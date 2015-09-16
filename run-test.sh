#!/bin/bash

source ~/torch/activate

# rm -Rf build

luarocks make rocks/clnn-scm-1.rockspec || exit 1

if [[ -z $LUAEXE ]]; then {
    LUAEXE=luajit
    # LUAEXE=lua
} fi
echo using luaexe: ${LUAEXE}

if [[ x${RUNGDB} == x1 ]]; then {
  rungdb.sh ${LUAEXE} test/test-clnn.lua
} else {
  ${LUAEXE} test/test-clnn.lua
} fi

