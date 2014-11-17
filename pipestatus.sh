#!/bin/bash

ls | grep 12345 | cd
echo ${PIPESTATUS[@]}
