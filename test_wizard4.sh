#!/bin/bash

# Test script with custom image
cd test-wizard9 || exit
echo -e "3\npython:3.12\ngit\ntest-py4\n/workspaces/test-py4\nvscode\nvscode" | ../dcutil-files/dcutil init wizard
