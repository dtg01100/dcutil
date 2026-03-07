#!/bin/bash

# Test script with different input order
cd test-wizard7 || exit
echo -e "2\npython\ngit,common-utils\ntest-py2\n/workspaces/test-py2\nvscode\nvscode" | ../dcutil-files/dcutil init wizard
