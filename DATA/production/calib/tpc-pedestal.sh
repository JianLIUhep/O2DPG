#!/usr/bin/env bash

source common/setenv.sh

source common/getCommonArgs.sh

source common/gen_topo_helper_functions.sh 

if [ $NUMAGPUIDS != 0 ]; then
  ARGS_ALL+=" --child-driver 'numactl --membind $NUMAID --cpunodebind $NUMAID'"
fi

PROXY_INSPEC="A:TPC/RAWDATA;dd:FLP/DISTSUBTIMEFRAME/0"
CALIB_INSPEC="A:TPC/RAWDATA;dd:FLP/DISTSUBTIMEFRAME/0"

CALIB_CONFIG="TPCCalibPedestal.LastTimeBin=12000;keyval.output_dir=/dev/null"

CCDB_PATH="http://o2-ccdb.internal"

HOST=localhost

#QC_CONFIG="consul-json://alio2-cr1-hv-con01.cern.ch:8500/o2/components/qc/ANY/any/tpc-pedestal-calib-qcmn"
QC_CONFIG="/o2/components/qc/ANY/any/tpc-pedestal-calib-qcmn"

max_events=50
publish_after=400

if [[ ! -z ${TPC_CALIB_MAX_EVENTS:-} ]]; then
    max_events=${TPC_CALIB_MAX_EVENTS}
fi

if [[ ! -z ${TPC_CALIB_PUBLISH_AFTER:-} ]]; then
    publish_after=${TPC_CALIB_PUBLISH_AFTER}
fi

EXTRA_CONFIG=" --publish-after-tfs ${publish_after} --max-events ${max_events} --lanes 36"


#################################################################################################################################


WORKFLOW=
add_W o2-dpl-raw-proxy "--dataspec \"$PROXY_INSPEC\" --inject-missing-data --channel-config \"name=readout-proxy,type=pull,method=connect,address=ipc://@tf-builder-pipe-0,transport=shmem,rateLogging=1\"" "" 0
add_W o2-tpc-calib-pad-raw "--input-spec \"$CALIB_INSPEC\"  --publish-after-tfs ${publish_after} --max-events ${max_events} --lanes 36" 
add_W o2-calibration-ccdb-populator-workflow "--ccdb-path \"http://o2-ccdb.internal\" " "" 0
add_QC_from_consul "${QC_CONFIG}" "--local --host localhost"

WORKFLOW+="o2-dpl-run ${ARGS_ALL} ${GLOBALDPLOPT}"

if [ $WORKFLOWMODE == "print" ]; then
  echo Workflow command:
  echo $WORKFLOW | sed "s/| */|\n/g"
else
  # Execute the command we have assembled
  WORKFLOW+=" --$WORKFLOWMODE ${WORKFLOWMODE_FILE}"
  eval $WORKFLOW
fi

#o2-dpl-raw-proxy ${ARGS_ALL} --inject-missing-data \
#    --dataspec "${PROXY_INSPEC}" \
#    --readout-proxy '--channel-config "name=readout-proxy,type=pull,method=connect,address=ipc://@tf-builder-pipe-0,transport=shmem,rateLogging=1"' \
#    | o2-tpc-calib-pad-raw ${ARGS_ALL} \
#    --input-spec "${CALIB_INSPEC}" \
#    --configKeyValues "${CALIB_CONFIG}" \
#    ${EXTRA_CONFIG} \
#    | o2-calibration-ccdb-populator-workflow ${ARGS_ALL} \
#    --ccdb-path ${CCDB_PATH} \
#    | o2-qc ${ARGS_ALL} --config ${QC_CONFIG} --local --host ${HOST} \
#   | o2-dpl-run ${ARGS_ALL} --dds ${WORKFLOWMODE_FILE} ${GLOBALDPLOPT}
