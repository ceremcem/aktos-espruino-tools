#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MODULES_DIR="${DIR}/modules"
AEA_MODULES="${DIR}/aktos-modules"


# compress: {
# sequences: true,
# dead_code: true,
# conditionals: true,
# booleans: true,
# unused: true,
# if_return: true,
# join_vars: true,
# drop_console: true
UGLIFYJS_OPTS="-m -c dead_code=true,if_return=true,unused=true,unsafe=true,hoist_vars=true"

lsc -cb init.ls

# create bundle
BUNDLE="app.min.js"
echo > ${BUNDLE}
BUNDLE_CONTENT=$(uglifyjs ${UGLIFYJS_OPTS} -- init.js)

# Get initial modules that are required in "init.ls"
req=$(echo ${BUNDLE_CONTENT} | grep -o 'require([\\\"a-zA-Z0-9]\+)' | sed 's|\\||g' | grep -o '".*"' | sed 's/"//g' | tr '\n' ' ')
MODULES=(`echo ${req}`)

# debug
for i in "${MODULES[@]}"; do echo "modules in init: $i"; done

# Register modules via `Modules.addCached()` method
# see: http://forum.espruino.com/comments/12899741/
i=0
while true; do
    MODULE_NAME="${MODULES[$i]}"
    if [[ -f "${MODULES_DIR}/${MODULE_NAME}.js" ]]; then
        echo "INFO: * Adding module: ${MODULE_NAME}"
        MODULE_STR=$(uglifyjs ${UGLIFYJS_OPTS} -- ${MODULES_DIR}/${MODULE_NAME}.js | sed 's/\"/\\\"/g' | sed "s/\n//g")
        echo "Modules.addCached(\"${MODULE_NAME}\", \"${MODULE_STR}\");" >> ${BUNDLE}
    elif [[ -f "${AEA_MODULES}/${MODULE_NAME}.ls" ]]; then 
        echo "INFO: ** Adding AKTOS module: '${MODULE_NAME}'"
        lsc -cbp ${AEA_MODULES}/${MODULE_NAME}.ls > ${AEA_MODULES}/${MODULE_NAME}.js || exit 1
        MODULE_STR=$(cat ${AEA_MODULES}/${MODULE_NAME}.js | uglifyjs ${UGLIFYJS_OPTS} | sed 's/\"/\\\"/g' | sed "s/\n//g")
        echo "Modules.addCached(\"${MODULE_NAME}\", \"${MODULE_STR}\");" >> ${BUNDLE}
    else
        echo "INFO: ?? Module '${MODULE_NAME}' is embedded??"
    fi


    # Add if any subdependency is required
    # ----------------------------------------
    req=$(cat ${BUNDLE} | grep -o 'require([\\\"a-zA-Z0-9]\+)' | sed 's|\\||g' | grep -o '".*"' | sed 's/"//g' | tr '\n' ' ')
    #echo "New dependencies: $req"
    SUB_DEPS=(`echo ${req}`)
    # add modules if not found in $MODULES
    for j in "${SUB_DEPS[@]}"; do
        #echo "DEBUG: looking for $j"
        add="yes"
        for k in "${MODULES[@]}"; do
            #echo "DEBUG: ......modules so far: $k"
            if [[ "$j" == "$k" ]]; then
                add="no"
                #echo "DEBUG: not adding module: $j"
                break
            fi
        done
        if [[ "$add" == "yes" ]]; then
            echo "... Adding sub dependency: $j"
            MODULES+=( "$j" )
        fi
    done


    i=$((i+1))
    num_of_modules=${#MODULES[@]}
    if (("$i" >= "$num_of_modules")) ; then 
        break
    fi
done 


echo ${BUNDLE_CONTENT}  >> ${BUNDLE}
