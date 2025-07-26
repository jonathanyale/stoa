TARGET := ".build"

# list all available recipes
default:
   @just -l

# build all programs
build:
   just ttgen
   nim c -d:release -o:{{TARGET}}/html ./src/html.nim
   
# format all source code
fmt:
   ruff format --config ~/.config/ruff.toml ./tools/*.py
   nimpretty --maxLineLen:89 --indent:3 ./src/*.nim

# generate transitions and format
ttgen:
   pypy ./tools/ttgen.py
   nimpretty --maxLineLen:89 --indent:3 ./src/transitions.nim

# clean build artifacts
clean:
   rm -rfd {{TARGET}}/**
