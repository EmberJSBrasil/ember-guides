#!/bin/bash
# requires apt packages: aspell, aspell-pt_BR

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

USE_LANGUAGE='pt_BR'

MARKDOWN_FILES_CHANGED=`(git diff --name-only $TRAVIS_COMMIT_RANGE || true) | grep .md`

if [ -z "$MARKDOWN_FILES_CHANGED" ]
then
    echo -e "$GREEN>> No markdown file to check $NC"

    exit 0;
fi

echo -e "$BLUE>> Following markdown files were changed in this pull request (commit range: $TRAVIS_COMMIT_RANGE):$NC"
echo "$MARKDOWN_FILES_CHANGED"

FOUND_LANGUAGES=`echo "$MARKDOWN_FILES_CHANGED" | xargs cat | grep "permalink: /" | sed -E 's/permalink: \/(fr|en)\/.*/\1/g'`
echo -e "$BLUE>> Languages recognized from the permalinks:$NC"
echo "$FOUND_LANGUAGES"

echo -e "$BLUE>> Will use this language as main one:$NC"
echo "$USE_LANGUAGE"

# cat all markdown files that changed
TEXT_CONTENT_WITHOUT_METADATA=`cat $(echo "$MARKDOWN_FILES_CHANGED" | sed -E ':a;N;$!ba;s/\n/ /g')`
# remove metadata tags
TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | grep -v -E '^(layout:|permalink:|date:|date_gmt:|authors:|categories:|tags:|cover:)(.*)'`
# remove { } attributes
TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/\{:([^\}]+)\}//g'`
# remove html
TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/<([^<]+)>//g'`
# remove code blocks
TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed  -n '/^\`\`\`/,/^\`\`\`/ !p'`
# remove links
TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/http(s)?:\/\/([^ ]+)//g'`

echo -e "$BLUE>> Text content that will be checked (without metadata, html, and links):$NC"
echo "$TEXT_CONTENT_WITHOUT_METADATA"

echo -e "$BLUE>> Checking in 'en' (many technical words are in English anyway)...$NC"
MISSPELLED=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | aspell --lang=en --encoding=utf-8 --add-extra-dicts=./scripts/aspell.en.pws list | sort -u`

echo -e "$BLUE>> Checking in '$USE_LANGUAGE' too..."
MISSPELLED=`echo "$MISSPELLED" | aspell --lang=$USE_LANGUAGE --encoding=utf-8 --add-extra-dicts=./scripts/aspell.$USE_LANGUAGE.pws list | sort -u`

NB_MISSPELLED=`echo "$MISSPELLED" | grep -Ev "^$" | wc -l`

if [ "$NB_MISSPELLED" -gt 0 ]
then
    echo -e "$RED>> Words that might be misspelled, please check:$NC"
    MISSPELLED=`echo "$MISSPELLED" | sed -E ':a;N;$!ba;s/\n/, /g'`
    echo "$MISSPELLED"
    COMMENT="$NB_MISSPELLED words might be misspelled, please check them: $MISSPELLED"

    echo -e "$BLUE>> Sending results in a comment on the Github pull request #$TRAVIS_PULL_REQUEST:$NC"
    curl -i -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST -d "{\"body\":\"$COMMENT\"}" \
        https://api.github.com/repos/ember-brasil/website/issues/$TRAVIS_PULL_REQUEST/comments
    exit 1
else
    COMMENT="No spelling errors, congratulations!"
    echo -e "$GREEN>> $COMMENT $NC"

    echo -e "$BLUE>> Sending results in a comment on the Github pull request #$TRAVIS_PULL_REQUEST:$NC"
    curl -i -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST -d "{\"body\":\"$COMMENT\"}" \
        https://api.github.com/repos/ember-brasil/website/issues/$TRAVIS_PULL_REQUEST/comments
    exit 0
fi
