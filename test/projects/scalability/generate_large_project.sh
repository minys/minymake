#!/bin/bash
#
# Generate a large project (1000 directories, 5000 files, 1000 modules)
#

SCRIPT=$(readlink -f ${BASH_SOURCE[0]})
CURDIR=${CURDIR:-$(dirname ${SCRIPT})}
ROOT=$(mktemp -d)

generate_module()
{
    local bin=bin.${2}

    cd ${1}/${2}
    (
        echo "bin := ${bin}"
        echo 'src := main.cc source1.cc source2.cc source3.cc source4.cc source5.cc'
    ) > module.mk

    echo "MODULES += ${2}/module.mk" >> ${ROOT}/GNUmakefile

    for file in source1 source2 source3 source4 source5; do
        (
            echo "#ifndef ${file}_guard"
            echo "#define ${file}_guard"
            echo "void ${file}_method(void);"
            echo "#endif"
        ) > ${file}.h
        (
            echo "#include \"${file}.h\""
            echo "void ${file}_method(void) {};"
        ) > ${file}.cc
    done

    (
        echo "#include \"source1.h\""
        echo "#include \"source2.h\""
        echo "#include \"source3.h\""
        echo "#include \"source4.h\""
        echo "#include \"source5.h\""
        echo "int main(void) {source1_method();source2_method();source3_method();source4_method();source5_method();return 0;}"
    ) > main.cc
}

touch ${ROOT}/GNUmakefile
ln -s ${CURDIR}/../../../build.mk ${ROOT}/build.mk

for dir in $(seq -s' ' 1 1000); do
    mkdir -p ${ROOT}/${dir}
    generate_module ${ROOT} ${dir}
done

echo "include build.mk" >> ${ROOT}/GNUmakefile

echo "Project generated in ${ROOT}"

exit 0
