
set -e

NAME="$1"
COMMIT="$2"
BRANCH="$3"
REGISTRY="$4"
REPO="$PWD"
SRC="$REPO-$COMMIT-src"

echo $NAME $COMMIT $REPO $SRC

err_handler() {
    echo "$NAME: Error on line $1 in file $0"
}

trap 'err_handler $LINENO' ERR

test -n "$NAME"
test -n "$COMMIT"
test -n "$REPO"
test -n "$BRANCH"

rm -rf "$SRC"
git clone $REPO "$SRC"

cd "$SRC"

TAGS="--tag=$NAME:$BRANCH"

test -z "$REGISTRY" || {
    TAGS="$TAGS --tag=$REGISTRY/$NAME:$BRANCH --tag=$REGISTRY/$NAME:$COMMIT";
}

docker build $TAGS "$SRC"

test -z "$REGISTRY" && {
    echo "Deployed to local $NAME at `date`, tags: $NAME:$BRANCH";

} || {
    docker push $REGISTRY/$NAME:$BRANCH;
    docker push $REGISTRY/$NAME:$COMMIT;
    echo "Deployed to registry $NAME at `date`, tags: $REGISTRY/$NAME:$BRANCH, $REGISTRY/$NAME:$COMMIT";
}

