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
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace TestSLIPEscaping
{
    class Program
    {
        static void Main(string[] args)
        {
            var md5 = MD5.Create();
            var rng = new Random();
            var fw = new byte[0x100000];
            var b = new byte[1];
            byte[] hash;
            int addr;
            bool success = false;
            short FlashParams = 0x0221;
            byte b2 = Convert.ToByte((FlashParams & 0xff00) >> 8);
            byte b3 = Convert.ToByte(FlashParams & 0xff);
            do
            {
                addr = rng.Next(0x100000);
                rng.NextBytes(b);
                fw[addr] = b[0];
                fw[2] = b2;
                fw[3] = b3;
                hash = md5.ComputeHash(fw);
                int match = 0;
                foreach (byte h in hash)
                {
                    if (h == 0xc0)
                        match++;
                    else if (h == 0xdb)
                        match++;
                    if (match == 2)
                    {
                        File.WriteAllBytes("TestSLIPEscaping.fac", fw);
                        success = true;
                        break;
                    }
                }
            }
            while (!success);
        }
    }
}
