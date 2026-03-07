#!/bin/bash

# Test script choosing detected template
cd test-wizard8 || exit
echo -e "1\ngit\ntest-py3\n/workspaces/test-py3\nvscode\nvscode" | ../dcutil-files/dcutil init wizard
