#!/bin/bash

# Author: Unknown

mysql -e "select engine,count(*),sum(index_length+data_length)/1024/1024 from information_schema.tables group by engine;"
