source /opt/Xilinx/2025.1/Vitis/settings64.sh

JOBS=`nproc 2> /dev/null || echo 1`

make -j $JOBS cores

make NAME=led_blinker all

make NAME=$1 bit

sudo sh scripts/alpine-project.sh $1
