#!/bin/sh
# executes only on single machine
# assumes 2 GPU devices available (if heterogeneous)

MPI=mpiexec
EXEC=$1
INPUT=$2
OUTPUT=$3
LOG=.verify_log

execname=$(basename "$EXEC" "")
inputdirname=$(dirname "$INPUT")
inputname=$(basename "$INPUT" ".gr")
extension=gr

FLAGS=
if [[ ($execname == *"bfs"*) || ($execname == *"sssp"*) ]]; then
  if [[ -f "${inputdirname}/${inputname}.source" ]]; then
    FLAGS+=" -srcNodeId=`cat ${inputdirname}/${inputname}.source`"
  fi
fi
if [[ $execname == *"worklist"* ]]; then
  FLAGS+=" -cuda_wl_dup_factor=3"
fi

source_file=${inputdirname}/source
if [[ $execname == *"cc"* ]]; then
  inputdirname=${inputdirname}/symmetric
  extension=sgr
elif [[ $execname == *"pull"* ]]; then
  inputdirname=${inputdirname}/transpose
  extension=tgr
fi
grep "${inputname}.${extension}" ${source_file} >>$LOG
INPUT=${inputdirname}/${inputname}.${extension}

if [ -z "$ABELIAN_GALOIS_ROOT" ]; then
  ABELIAN_GALOIS_ROOT=/net/velocity/workspace/SourceCode/GaloisCpp
fi
checker=${ABELIAN_GALOIS_ROOT}/exp/scripts/result_checker.py

hostname=`hostname`

SET=
if [[ $execname == *"vertex-cut"* ]]; then
  if [[ $inputname == *"road"* ]]; then
    exit
  fi
  if [ -z "$ABELIAN_NON_HETEROGENEOUS" ]; then
    # assumes only one GPU device available
    SET="cc,2,2 gg,2,2 gc,2,2 cg,2,2"
  else
    SET="cc,2,2 cccc,4,2 cccccccc,8,2"
  fi
else
  if [ -z "$ABELIAN_NON_HETEROGENEOUS" ]; then
    # assumes only one GPU device available
    SET="c,1,4 g,1,4 cc,2,2 gg,2,2 gc,2,2 cg,2,2"
  else
    SET="c,1,4 cc,2,2 cccc,4,2 cccccccc,8,2"
  fi
fi

fail=0
failed_cases=""
for task in $SET; do
  IFS=",";
  set $task;
  PFLAGS=$FLAGS
  if [[ $execname == *"vertex-cut"* ]]; then
    PFLAGS+=" -partFolder=${inputdirname}/partitions/${2}/${inputname}.${extension}"
  elif [[ ($1 == *"gc"*) || ($1 == *"cg"*) ]]; then
    PFLAGS+=" -scalegpu=3"
  fi
  rm -f output_*.log
  echo "GALOIS_DO_NOT_BIND_THREADS=1 $MPI -n=$2 ${EXEC} ${INPUT} -pset=$1 -t=$3 ${PFLAGS} -comm_mode=2 -verify -runs=1" >>$LOG
  eval "GALOIS_DO_NOT_BIND_THREADS=1 $MPI -n=$2 ${EXEC} ${INPUT} -pset=$1 -t=$3 ${PFLAGS} -comm_mode=2 -verify -runs=1" >>$LOG 2>&1
  outputs="output_${hostname}_0.log"
  i=1
  while [ $i -lt $2 ]; do
    outputs+=" output_${hostname}_${i}.log"
    let i=i+1
  done
  eval "python $checker $OUTPUT ${outputs} &> .output_diff"
  cat .output_diff >> $LOG
  if ! grep -q "SUCCESS" .output_diff ; then
    let fail=fail+1
    failed_cases+="$1 devices with $3 threads; "
  fi
  rm .output_diff
done

rm -f output_*.log

echo "---------------------------------------------------------------------------------------"
echo "Algorithm: " $execname
echo "Input: " $inputname
if [[ $fail == 0 ]] ; then
  echo "Status: SUCCESS"
else
  echo "Status: FAILED"
  echo $fail "failed test cases:" $failed_cases
fi
echo "---------------------------------------------------------------------------------------"

