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
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using PackageFW.Data;

namespace PackageFW
{
    class Program
    {
        public static bool Verbose;
        public static bool NoCompression;
        static bool Interactive;
        static string InputFile;
        static string OutputFile;
        static byte[] InputBytes;
        static List<byte> OutputBytes;
        static short FlashParams = 0;
        static string Version = "0.0.0.0";
        static short BlockSize;

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("Packaging ESP factory firmware into NXESP format...");
                Interactive = args.Any(a => a == "-i");
                if (Interactive)
                    Console.WriteLine("Running in interactive mode");
                Verbose = args.Any(a => a == "-v");
                if (Verbose)
                    Console.WriteLine("Running in verbose mode");
                NoCompression = args.Any(a => a == "-nc");
                Console.WriteLine("Expecting input file to be " + (NoCompression ? "precompressed with -md5 provided" : "uncompressed"));
                if (args.Length < 2)
                    return Help();

                // Input file
                InputFile = (args[0] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(InputFile))
                    return Help();
                if (!File.Exists(InputFile))
                    return Error("Input file \"" + InputFile + "\" doesn't exist.");
                try
                {
                    InputBytes = File.ReadAllBytes(InputFile);
                }
                catch { }
                if (InputBytes == null || InputBytes.Length == 0)
                    return Error("Cannot open input file \"" + InputFile + "\".");
                Console.WriteLine("Input firmware: " + InputBytes.Length + " bytes (" 
                    + (NoCompression ? "pre" : "un") + "compressed)");
                if (!NoCompression && InputBytes.Length < 0x100000) // 1MB
                {
                    var ib = InputBytes.ToList();
                    Pad(ib, 0x100000);
                    InputBytes = ib.ToArray();
                    Console.WriteLine("Padding uncompressed input firmware to: " + InputBytes.Length + " bytes");
                }

                // Output file
                OutputFile = (args[1] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(OutputFile))
                    return Help();

                // Flash Params
                var header = new NxEspHeader();
                string fp = (args.FirstOrDefault(a => a.StartsWith("-f=0x")) ?? "     ").Substring(5);
                short.TryParse(fp, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out FlashParams);
                header.FlashParams = FlashParams;
                Console.WriteLine("Flash params: 0x" + FlashParams.ToString("X4"));

                // Version
                string ver = (args.FirstOrDefault(a => a.StartsWith("-v=")) ?? "   ").Substring(3).Trim();
                if (!string.IsNullOrWhiteSpace(ver))
                    Version = ver;
                header.Version = Version;
                Console.WriteLine("Version: " + Version);

                // Block Size
                string arg = (args.FirstOrDefault(a => a.StartsWith("-b=")) ?? "   ").Substring(3).Trim();
                short.TryParse(arg, out BlockSize);
                if (BlockSize <= 0)
                    BlockSize = 16384;
                header.DataBlockSize = BlockSize;
                Console.WriteLine("Block size: 0x" + BlockSize.ToString("X2"));

                // Precalculated MD5 hash
                if (NoCompression)
                {
                    string md5Arg = (args.FirstOrDefault(a => a.StartsWith("-md5=")) ?? "      ").Substring(5).Trim();
                    Console.WriteLine("MD5 Hash: " + md5Arg + " (supplied)");
                    if (md5Arg.Length != 32)
                        return Error("MD5 Hash must be 32 characters long.");
                    header.Md5 = HexToBytes(md5Arg);
                    header.PreCompressed = true;
                }

                // Set flash params
                if (!NoCompression)
                {
                    InputBytes[2] = Convert.ToByte((FlashParams & 0xff00) >> 8);
                    InputBytes[3] = Convert.ToByte(FlashParams & 0xff);
                }

                // Calculate MD5 hash
                if (!NoCompression)
                {
                    using (MD5 md5 = MD5.Create())
                    {
                        header.Md5 = md5.ComputeHash(InputBytes); // 16 bytes of binary, not hex string
                        string hash = BitConverter.ToString(header.Md5).Replace("-", "").ToLowerInvariant();
                        Console.WriteLine("MD5 Hash: " + hash + " (calculated)");
                    }
                }

                OutputBytes = new List<byte>();
                Console.WriteLine("Converting to NXESP format...");
                OutputBytes.AddRange(header.Serialize(InputBytes));
                Console.WriteLine("Output file: " + OutputBytes.Count + " bytes");
                Console.WriteLine("Writing output file...");
                File.WriteAllBytes(OutputFile, OutputBytes.ToArray());

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

        static int Error(string Msg)
        {
            Console.WriteLine(Msg ?? "");
            return 1;
        }

        static int Help()
        {   //                 12345678901234567890123456789012345678901234567890123456789012345678901234567890
            Console.WriteLine("Usage:");
            Console.WriteLine("  PackageFW.exe <DotCommandPathAndFile> <FirmwarePathAndFile> [f=<FlashParams>]\r\n" 
                            + "  [-v=<Version>] [-b=<BlockSize>] [-i]");
            return 1;
        }

        static void Pad(List<byte> Output, int Size)
        {
            if (Output.Count > Size)
                throw new InvalidDataException("Output is already larger than 0x" + Size.ToString("X2") + ".");
            Output.AddRange(Enumerable.Repeat(Convert.ToByte(0xff), Size - Output.Count));
        }

        static byte[] HexToBytes(string hex)
        {
            return Enumerable.Range(0, hex.Length)
                .Where(x => x % 2 == 0)
                .Select(x => Convert.ToByte(hex.Substring(x, 2), 16))
                .ToArray();
        }
    }
}
