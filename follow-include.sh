function followInclude() {
  confFile="${1}"
  isCompressed="${2}"
# From the logrotate.conf man page:
#       include file_or_directory
#              Reads the file given as an argument as if it was included inline
#              where  the  include  directive appears. If a directory is given,
#              most of the files in that directory are read in alphabetic order
#              before  processing  of  the  including  file continues. The only
#              files which are ignored are files which are  not  regular  files
#              (such  as directories and named pipes) and files whose names end
#              with one of the taboo extensions, as specified by  the  tabooext
#              directive.
#       tabooext [+] list
#              The  current  taboo  extension  list is changed (see the include
#              directive for information on the taboo extensions). If a +  pre‐
#              cedes  the  list of extensions, the current taboo extension list
#              is augmented, otherwise it is replaced. At  startup,  the  taboo
#              extension   list  contains  .rpmsave,  .rpmorig,  ~,  .disabled,
#              .dpkg-old,   .dpkg-dist,   .dpkg-new,   .dpkg-bak,    .dpkg-del,
#              .cfsaved,   .ucf-old,   .ucf-dist,   .ucf-new,   .rpmnew,  .swp,
#              .cfsaved, .rhn-cfg-tmp-*
  Test filehandle type:
    if dir, recurse on each thing
    else if regular file, enter while loop.
    else skip non-regular files 
  while read LINE; do
    if it's a compression line, set isCompressed
    else if include line, recurse: 
      if file, recurse: followInclude
      if dir, 
  done < "${confFile}"
  
}

