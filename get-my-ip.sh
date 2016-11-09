get_my_ip() {
  # Could screen-scrape Google:
  #https://www.google.com/#q=what+is+my+ip
  local -a FILES
  local -a DOMAINS
  DOMAINS+=("icanhazip.com")
  DOMAINS+=("api.ipify.org")
  DOMAINS+=("bot.whatismyipaddress.com")

  # Use curly-braces to silence bash job-control debug output
  {
    for DOMAIN in ${DOMAINS[@]}; do
      FILE=$(mktemp)
      FILES+=("${FILE}")
      curl -s4 "${DOMAIN}" > "${FILE}" &
    done
    i=0
    while [[ $i -lt 10 ]]; do
      i=$(( $i + 1 ))
      if grep -qP '(\d{1,3}\.){3}\d{1,3}' ${FILES[@]}; then
        # We got an IP.  Exit.
        break
      elif [[ $( jobs -r | wc -l ) -gt 0 ]]; then
        # Jobs still running.  Wait & retry.
        sleep 0.5
        continue
      else
        # No IP returned, no jobs running.  Error.
        echo "ERROR: Unable to determine my public IP" >&2
        return
      fi
    done
  } 2>/dev/null # End silenced debug output

  # Read my IP from the tmpfiles
  MyIP=$( grep -P '(\d{1,3}\.){3}\d{1,3}' ${FILES[@]} |
            cut -d: -f2 | 
            sort -u |
            head -n 1 )
  # Clean up my leftover procs & tempfiles
  for PID in $( jobs -p ); do kill $PID &>/dev/null; done
  for FILE in ${FILES[@]}; do rm -f "${FILE}"; done
  echo "$MyIP"
}
get_my_ip


