#! /bin/bash

set -o errexit
set -o nounset

if [[ "$TRAVIS_BRANCH" == "release" && "$FAVORITE_CONFIG" != "yes" ]]
then
  echo "This is a release branch and there's nothing this matrix element must do."
  exit 0
fi

install_ponyc(){
  echo -e "\033[0;32mInstalling latest ponyc release\033[0m"
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "8756 C4F7 65C9 AC3C B6B8  5D62 379C E192 D401 AB61"
  echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
  sudo apt-get update
  sudo apt-get -V install ponyc
}

install_pony_stable(){
  sudo apt-get install git
  pushd /tmp
  git clone https://github.com/ponylang/pony-stable.git
  cd pony-stable
  git checkout $STABLE_VERSION
  make
  sudo make install
  popd
}

install_ponyc
install_pony_stable
