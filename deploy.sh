#!/bin/bash -ex
git checkout gh-pages
git reset  # Make sure no extraneous files are staged
git merge master --no-edit
grunt

# Don't commit if no diff
if [[ ! -z $(git diff) ]]; then
    git commit -am "[RELEASE] Updated application.min.js"
    git push origin gh-pages
fi

git checkout -


