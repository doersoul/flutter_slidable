## init
dart pub global activate melos

export $PATH:...

melos exec -- flutter pub upgrade --major-versions

## sync master
git remote add upstream https://github.com/letsar/flutter_slidable.git

git fetch upstream

git merge upstream/master

20250527 a510f1e
