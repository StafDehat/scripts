#!/bin/bash
function xterm-title() {
  newTitle="${@}"
  cat <<EOF
PROMPT_COMMAND='\
echo -ne "\033]0;'"${newTitle}"'\007";'
EOF

}

