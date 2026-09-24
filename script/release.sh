#!/bin/bash
# Cuts a Nameatic release: bumps the version, collects release notes, builds a
# notarized app, publishes a GitHub release, and adds it to the Sparkle appcast
# on the gh-pages branch.
#
#   script/release.sh                 prompts for the version (default: patch bump)
#   script/release.sh 1.2             explicit version
#   script/release.sh minor           major | minor | patch bump of the current version
#
# Options:
#   --notes-file FILE   use FILE as the release notes instead of opening $EDITOR
#   --dry-run           build and generate the appcast entry, but commit, tag and
#                       publish nothing (Info.plist is restored afterwards)
#
# Needs everything script/build-app.sh --release needs, plus a logged-in `gh`
# and the Sparkle EdDSA private key in the login keychain (generate_keys).
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="deskrabbits/nameatic"
SITE="https://deskrabbits.github.io/nameatic"
PLIST="Resources/Info.plist"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"
WORK="build/release"
SCISSORS="# ------------------------ >8 ------------------------"

die() { echo "error: $*" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "$1" "$PLIST"; }
interactive() { [ -t 0 ] && [ -t 1 ]; }

VERSION_ARG=""
NOTES_FILE=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --notes-file) NOTES_FILE="${2:?--notes-file needs a path}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$VERSION_ARG" ] || die "more than one version given"; VERSION_ARG="$1"; shift ;;
  esac
done
if [ -n "$NOTES_FILE" ]; then
  [ -s "$NOTES_FILE" ] || die "notes file $NOTES_FILE is missing or empty"
  NOTES_FILE="$(cd "$(dirname "$NOTES_FILE")" && pwd)/$(basename "$NOTES_FILE")"
fi

# --- Preflight ---------------------------------------------------------------

[ "$(git branch --show-current)" = "main" ] || die "releases are cut from main"
[ -z "$(git status --porcelain)" ] || die "working tree has uncommitted changes"
gh auth status >/dev/null 2>&1 || die "gh is not logged in (run: gh auth login)"
git fetch -q origin main gh-pages
git merge-base --is-ancestor origin/main HEAD || die "main is behind or has diverged from origin/main"

# --- Version -----------------------------------------------------------------

CUR_VERSION="$(plist "Print :CFBundleShortVersionString")"
CUR_BUILD="$(plist "Print :CFBundleVersion")"

bump() { # bump <version> <major|minor|patch>
  local IFS=. parts
  read -ra parts <<< "$1"
  local major="${parts[0]}" minor="${parts[1]:-0}" patch="${parts[2]:-0}"
  case "$2" in
    major) echo "$((major + 1)).0" ;;
    minor) echo "$major.$((minor + 1))" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
  esac
}

VERSION="$VERSION_ARG"
if [ -z "$VERSION" ]; then
  interactive || die "no version given (pass one, or major/minor/patch)"
  SUGGESTED="$(bump "$CUR_VERSION" patch)"
  echo "Current version: $CUR_VERSION (build $CUR_BUILD)"
  read -rp "New version, or major/minor/patch [$SUGGESTED]: " VERSION
  VERSION="${VERSION:-$SUGGESTED}"
fi
case "$VERSION" in
  major|minor|patch) VERSION="$(bump "$CUR_VERSION" "$VERSION")" ;;
esac
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || die "version must look like 1.2 or 1.2.3, got '$VERSION'"
[ "$(printf '%s\n%s\n' "$CUR_VERSION" "$VERSION" | sort -V | head -1)" = "$CUR_VERSION" ] \
  || die "$VERSION is older than the current version $CUR_VERSION"
TAG="v$VERSION"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git ls-remote --exit-code --tags origin "$TAG" >/dev/null; then
  die "tag $TAG already exists"
fi
BUILD=$((CUR_BUILD + 1))
echo "Releasing Nameatic $VERSION (build $BUILD)"

# --- Release notes -----------------------------------------------------------
# Collected before the build so the long notarization wait needs no attention.

rm -rf "$WORK"
mkdir -p "$WORK/appcast"
NOTES="$WORK/appcast/Nameatic-$VERSION.md"   # must share the zip's basename for generate_appcast

if [ -n "$NOTES_FILE" ]; then
  cp "$NOTES_FILE" "$NOTES"
else
  interactive || die "no terminal to edit release notes in (use --notes-file)"
  LAST_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
  {
    echo
    echo "$SCISSORS"
    echo "# Write the release notes for Nameatic $VERSION above this line, in Markdown."
    echo "# Everything from the line above down is ignored."
    echo "#"
    if [ -n "$LAST_TAG" ]; then
      echo "# Commits since $LAST_TAG:"
      git log --format='#   %s' "$LAST_TAG..HEAD"
    else
      echo "# Commits so far:"
      git log --format='#   %s'
    fi
    for tag in $(gh release list --repo "$REPO" --limit 3 --json tagName --jq '.[].tagName'); do
      echo "#"
      echo "# ===== Notes for $tag ====="
      gh release view "$tag" --repo "$REPO" --json body --jq .body | sed 's/^/#   /'
    done
  } > "$NOTES"
  ${VISUAL:-${EDITOR:-vi}} "$NOTES"
  # Drop everything from the scissors line down, then trailing blank lines.
  sed -i '' "/^$SCISSORS\$/,\$d" "$NOTES"
  printf '%s\n' "$(cat "$NOTES")" > "$NOTES"
  grep -q '[^[:space:]]' "$NOTES" || die "release notes are empty, aborting"
  echo
  echo "----- Release notes for $VERSION -----"
  cat "$NOTES"
  echo "--------------------------------------"
  read -rp "Build and publish Nameatic $VERSION with these notes? [y/N] " ok
  [[ "$ok" =~ ^[Yy] ]] || die "aborted"
fi

# --- Build -------------------------------------------------------------------

# Until the release commit exists, a failure puts Info.plist back.
restore_plist() { git checkout -q -- "$PLIST"; }
trap restore_plist EXIT

plist "Set :CFBundleShortVersionString $VERSION"
plist "Set :CFBundleVersion $BUILD"

script/build-app.sh --release
ZIP="build/Nameatic-$VERSION.zip"
[ -f "$ZIP" ] || die "build did not produce $ZIP"

# --- Appcast entry -----------------------------------------------------------

cp "$ZIP" "$WORK/appcast/"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  --embed-release-notes \
  --link "$SITE/" \
  --maximum-deltas 0 \
  "$WORK/appcast"

# The gh-pages checkout: an existing worktree if there is one, else our own.
PAGES="$(git worktree list --porcelain | awk '/^worktree /{sub(/^worktree /, ""); wt=$0} $0=="branch refs/heads/gh-pages"{print wt}')"
if [ -z "$PAGES" ]; then
  PAGES="build/gh-pages"
  git worktree add -q "$PAGES" gh-pages
fi
[ -z "$(git -C "$PAGES" status --porcelain)" ] || die "gh-pages checkout at $PAGES has uncommitted changes"
git -C "$PAGES" merge -q --ff-only origin/gh-pages || die "gh-pages has diverged from origin/gh-pages"

# Splice the new <item> in as the newest entry, keeping existing entries as-is.
python3 - "$WORK/appcast/appcast.xml" "$PAGES/appcast.xml" "$BUILD" <<'PY'
import re, sys, textwrap
new_path, feed_path, build = sys.argv[1:]
item = re.search(r"[ \t]*<item>.*?</item>\n", open(new_path).read(), re.S)
if not item:
    sys.exit("generate_appcast produced no <item>")
feed = open(feed_path).read()
if f"<sparkle:version>{build}</sparkle:version>" in feed:
    sys.exit(f"appcast already has an entry for build {build}")
# generate_appcast indents with 4 spaces per level, the feed with 2; halve the
# indentation of every line outside the release notes' CDATA block.
text, in_cdata = "", False
for line in item.group(0).splitlines(keepends=True):
    if not in_cdata:
        stripped = line.lstrip(" ")
        line = " " * ((len(line) - len(stripped)) // 2) + stripped
    if "<![CDATA[" in line:
        in_cdata = True
    if "]]>" in line:
        in_cdata = False
    text += line
anchor = re.search(r"[ \t]*<item>", feed) or re.search(r"[ \t]*</channel>", feed)
feed = feed[:anchor.start()] + text + feed[anchor.start():]
open(feed_path, "w").write(feed)
PY

# Point the site's download button and version label at this release.
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/Nameatic-$VERSION.zip"
perl -pi -e "s#(id=\"download-link\" href=\")[^\"]*#\${1}$DOWNLOAD_URL#; s#(id=\"version-label\">)Version [^ ]+#\${1}Version $VERSION#" "$PAGES/index.html"

if [ "$DRY_RUN" = "1" ]; then
  echo
  git -C "$PAGES" --no-pager diff --stat
  git -C "$PAGES" checkout -q -- .
  echo "Dry run: built $ZIP and generated $WORK/appcast/appcast.xml."
  echo "Nothing was committed, tagged or published; Info.plist and gh-pages are unchanged."
  exit 0
fi

# --- Publish -----------------------------------------------------------------

git commit -q -m "Release Nameatic $VERSION" -- "$PLIST"
git tag -a "$TAG" -m "Nameatic $VERSION"
trap - EXIT
git push -q origin main "$TAG"

gh release create "$TAG" "$ZIP" --repo "$REPO" --verify-tag \
  --title "Nameatic $VERSION" --notes-file "$NOTES"

# Only now that the download exists does the appcast advertise it.
git -C "$PAGES" add appcast.xml index.html
git -C "$PAGES" commit -q -m "Nameatic $VERSION"
git -C "$PAGES" push -q origin gh-pages

echo
echo "Released Nameatic $VERSION"
echo "  https://github.com/$REPO/releases/tag/$TAG"
echo "  $SITE/appcast.xml (GitHub Pages takes a minute or two to update)"
