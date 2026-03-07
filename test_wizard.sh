#!/bin/bash

# Simple test script using echo to simulate input
cd test-wizard6 || exit
echo -e "2\npython\ngit\ntest-py\n/workspaces/test-py\nvscode\nvscode" | ../dcutil-files/dcutil init wizard
