#!/bin/bash

[ $[ $RANDOM % 6 ] == 0 ] && banner BANG || echo '*click*'
