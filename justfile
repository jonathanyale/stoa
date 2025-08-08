TARGET := ".build"

# list all available recipes
default:
   @just -l

# build the compiler
build:
   just ttgen
   nim c -d:release -o:{{TARGET}}/html ./src/html.nim
   
# format all source code
fmt:
   ruff format --config ~/.config/ruff.toml ./tools/*.py
   nimpretty --maxLineLen:89 --indent:3 ./src/*.nim
   prettier -uw --print-width 79  --tab-width 3 ./readme.md

# generate transitions and format
ttgen:
   pypy ./tools/ttgen.py
   nimpretty --maxLineLen:89 --indent:3 ./src/transitions.nim

# run the compiler over a source dir into an output dir
run input="stoae" output="blogs":
   just build
   {{TARGET}}/html --input={{input}} --output={{output}}

# clean build artifacts
clean:
   rm -rfd {{TARGET}}/**
