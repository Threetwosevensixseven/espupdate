//  Copyright 2020 Robin Verhagen-Guest
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CombineFW
{
    class Program
    {
        static bool Interactive;

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("Appending NXESP formatted firmare to ESPUPDATE dot command...");
                Interactive = args.Any(a => a == "-i");
                if (Interactive)
                    Console.WriteLine("Running in interactive mode");

                var output = new List<byte>();

                // 0x00000
                var boot = File.ReadAllBytes(@"C:\spec\next\esp\AT_V1.1_on_ESP8266_NONOS_SDK_V1.5.4\AT_bin\boot_v1.5.bin");

                // 0x01000
                var user = File.ReadAllBytes(@"C:\spec\next\esp\AT_V1.1_on_ESP8266_NONOS_SDK_V1.5.4\AT_bin\512+512\user1.1024.new.2.bin");

                // 0xFE000
                //var blank = File.ReadAllBytes(@"C:\spec\next\esp\AT_V1.1_on_ESP8266_NONOS_SDK_V1.5.4\AT_bin\blank.bin");

                // 0xFC000
                var init = File.ReadAllBytes(@"C:\spec\next\esp\AT_V1.1_on_ESP8266_NONOS_SDK_V1.5.4\AT_bin\esp_init_data_default.bin");

                output.AddRange(boot);
                Pad(output, 0x01000);

                output.AddRange(user);
                Pad(output, 0xFC000);

                output.AddRange(init);
                Pad(output, 0x100000);

                File.WriteAllBytes(@"C:\Users\robin\Documents\Visual Studio 2015\Projects\espupdate\fw\ESP8266_FULL_V3.3_SPUGS\NONOS_v1_5_4_0.bin", 
                    output.ToArray());

                return 0;
            }
            finally
            {
                if (Interactive)
                {
                    Console.WriteLine();
                    Console.WriteLine("Press any key to continue...");
                    Console.ReadKey();
                }
            }
        }

        static void Pad(List<byte> Output, int Size)
        {
            if (Output.Count > Size)
                throw new InvalidDataException("Output is already larger than 0x" + Size.ToString("X2") + ".");
            Output.AddRange(Enumerable.Repeat(Convert.ToByte(0xff), Size - Output.Count));
        }
    }
}
