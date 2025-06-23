#!/bin/bash
SCRIPT=eosupgrader
echo ${SCRIPT}
CFLAGS="-static" shc -r -v -f ${SCRIPT}.sh -o ${SCRIPT}

zip ${SCRIPT}.zip ${SCRIPT}