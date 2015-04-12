
// ======================================================================== //
// Copyright 2009-2015 Intel Corporation                                    //
//                                                                          //
// Licensed under the Apache License, Version 2.0 (the "License");          //
// you may not use this file except in compliance with the License.         //
// You may obtain a copy of the License at                                  //
//                                                                          //
//     http://www.apache.org/licenses/LICENSE-2.0                           //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
// ======================================================================== //


// enable the "mpi distributed" part of the ospray api
#if !OSPRAY_MPI_DISTRIBUTED
#  define OSPRAY_MPI_DISTRIBUTED 1
#endif

#include <ospray/ospray.h>

namespace ospray {
  void testDistributedApp(int &ac, char **&av)
  {
    PING;
    ospMpiInit(&ac,&av,OSP_MPI_Z_COMPOSITE);
  }
}

int main(int ac, char **av)
{
  ospray::testDistributedApp(ac,av);
  return 0;
}
