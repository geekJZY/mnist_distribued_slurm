#!/bin/bash
##NMENT SETTINGS; CHANGE WITH CAUTION
#SBATCH --export=ALL                #Propagate environment
#SBATCH --get-user-env=L             #Replicate login environment

##NECESSARY JOB SPECIFICATIONS
#SBATCH --job-name=test_distributed     #Set the job name to "JobExample4"
#SBATCH --time=1:00:00                #Set the wall clock limit to 1hr and 30min
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1                 #Request 1 tasks
#SBATCH --cpus-per-task=20          # multithreads
#SBATCH --mem=30000M                  #Request 2560MB (2.5GB) per node
#SBATCH --output=imagenet.%j      #Send stdout/err to "Example4Out.[jobID]"
#SBATCH --gres=gpu:2                 #Request 1 GPU per node can be 1 or 2
#SBATCH --partition=gpu
#SBATCH --exclusive
#SBATCH --wait-all-nodes=1

MASTER=`/bin/hostname -s`
SLAVES=`scontrol show hostnames $SLURM_JOB_NODELIST | grep -v $MASTER`
#Make sure this node (MASTER) comes first
HOSTLIST="$MASTER $SLAVES"
echo $HOSTLIST

#Get a random unused port on this host(MASTER) between 2000 and 9999
#First line gets list of unused ports
#2nd line restricts between 2000 and 9999
#3rd line gets single random port from the list
MPORT=`ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{5,5\}" | sort | uniq | shuf -n1`
echo "MPORT is ${MPORT}"

NPROCS_PER_NODE=2
SLURM_JOB_NUM_NODES=2

module load Anaconda3/2020.07
source activate /scratch/user/xueq13/.conda/envs/pytorch

#Launch the pytorch processes, first on master (first in $HOSTLIST) then
#on the slaves
RANK=0
for node in $HOSTLIST; do
        echo 'ssh to:' $node
        srun --nodes 1 --ntasks 1 --exclusive -w $node \
        python -m torch.distributed.launch \
        --nproc_per_node=$NPROCS_PER_NODE \
        --nnodes=$SLURM_JOB_NUM_NODES \
        --node_rank=$RANK \
        --master_addr="$MASTER" --master_port="$MPORT" \
        main.py &
        RANK=$((RANK+1))
done
wait

echo job done!

