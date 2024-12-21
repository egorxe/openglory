import subprocess as sp
import sys

class GpuPipelineStage():
    def __init__(self, config, stage_num, fifos):
        stage_config = config["stages"][stage_num]
        self.stage_num = stage_num

        # launch stage binary
        print("Pipeline stage", stage_num, stage_config["comment"] + ":", "launching binary", stage_config["binary"])
        self.executor = sp.Popen([stage_config["binary"], str(config["display_size_x"]), str(config["display_size_y"]), fifos[0], fifos[1]], stdout=sys.stdout, stderr=sys.stdout)
        
    def Stop(self):
        self.executor.terminate()
        
    def CheckAlive(self):
        return (self.executor.poll() is None)
            
