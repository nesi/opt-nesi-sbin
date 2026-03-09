#!/bin/bash


# look into $DIR and tar all subdirectories, then sync to Freezer

# directory containing subdirectories to tar
#DIR="/nesi/project/nesi99999/vfan001/freezer/test_directory2/"
DIR=""
PREFETCH=FALSE
#FREEZER="s3://project-9776/test/"
FREEZER="s3://project-alloc/"
#FREEZER="s3://nearline-9776/vfan001/test/"

print_usage() {
    echo "tars subdirectories in directory and syncs to Freezer."
    echo ""
    echo "Usage: $0 [-h] [-d <directory with subdirs to tar>] [-p <FALSE/TRUE weka prefetch>] [-f Freezer directory]"
    echo ""
    echo "  -h      Display this help message"
    echo "  -d      Directory containing subdirectories to individually tar"
    echo "  -p      Weka fs prefetch FALSE/TRUE. Please check the largest subdirectory can fit in Weka SSD before enabling"
    echo "  -f      Freezer location to sync data eg s3://nearline-9776/vfan001/test/"
    exit 0
}

main(){
    # Check for arguments and call usage() if necessary
    if [[ "$#" -eq 0 ]]; then
        print_usage # This call works because usage() is defined above
    fi


    while getopts "d:p:f:" flag; do
        case "${flag}" in
            d)
            # add slash to end of $DIR to ensure able to look for sub-dirs
            DIR="${OPTARG}/"
            ;;
            p)
            PREFETCH="${OPTARG}"
            ;;
            f)
            FREEZER="${OPTARG}"
            ;;
            *)
            print_usage
            ;;
        esac
    done

    
    printf "dir: ${DIR} \nweka prefetch: ${PREFETCH}\nfreezer: ${FREEZER}\n"
    printf "**************\n\n"

    tar_directories ${DIR} ${PREFETCH}
    freezer_sync ${FREEZER}
    printf "\U1F600\n"
}

tar_directories(){
    DIR=$1
    WEKAFETCH=$2
  
    if [[ ! -d "$DIR" ]]; then
        printf "directory ${DIR} does not exist, exiting...\n"
        exit 1
    fi

    for d in ${DIR}*/ ; do
        [ -d "$d" ] || continue
    
        # run the next 'find' line ONLY if each directory will fit on SSD
        #weka fs tier fetch ${d}
        if [[ "${WEKAFETCH}" == "TRUE" ]]; then
            printf "weka fs pre-fetching - ${d}\n"
        #    find ${d} -type f  -print0 | xargs -0 -r -P 8 weka fs tier fetch
        else
            printf "No weka prefetch\n"
        fi
        
        printf "tar-ing ${d}\n"
        #tar -czf "${d%/}.tar.gz" "$d"
        
        # weka fs tier release ${d}
        if [[ "${WEKAFETCH}" == "TRUE" ]]; then
            printf "weka fs releasing - ${d}\n\n"
          #  find "${d}" -type f  -print0 | xargs -0 -r -P 8 weka fs tier release
        fi
    done
    printf "finished tar directories step\n\n"
    printf " ----------\n\n"
}


# upload to Freezer
freezer_sync(){
    FREEZERPATH=$1
    
    if ( ! s3cmd ls ${FREEZERPATH} ) ; then
        printf "Freezer path does not exist: ${FREEZERPATH}\n\n"
        exit 1
    fi

    printf "sync to Freezer\n\n"
    for j in *.tar.gz ; do
        #echo ${j}
        echo "s3cmd sync --verbose ${j} ${FREEZERPATH}/${j}/"
        s3cmd sync --verbose ${j} ${FREEZERPATH}${j}/
    done
}

# -- main body ---
main $@