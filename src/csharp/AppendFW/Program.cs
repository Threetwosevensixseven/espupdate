using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
//using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using ZLibNet;

namespace AppendFW
{
    class Program
    {
        static bool Interactive;
        static int Size;
        static string DotCommand;
        static string Firmware;
        static short FlashParams = 0;
        static string Version = "0.0.0.0";

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("Appending firmware...");
                Interactive = args.Any(a => a == "-i");
                if (Interactive)
                    Console.WriteLine("Running in interactive mode");

                if (args.Length < 3)
                    return Help();

                int.TryParse(args[0], out Size);
                if (Size <= 0)
                    return Help();

                var header = new NxEspHeader();
                string fp = (args.FirstOrDefault(a => a.StartsWith("-f=0x")) ?? "").Trim().Substring(5);
                short.TryParse(fp, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out FlashParams);
                header.FlashParams = FlashParams;
                //Console.WriteLine("FlashParams: 0x" + FlashParams.ToString("X4"));

                string ver = (args.FirstOrDefault(a => a.StartsWith("-v=")) ?? "").Trim().Substring(3).Trim();
                if (!string.IsNullOrWhiteSpace(ver))
                    Version = ver;
                header.Version = Version;
                //Console.WriteLine("Version: " + Version);

                DotCommand = (args[1] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(DotCommand))
                    return Help();
                if (!File.Exists(DotCommand))
                    return Error("Dot command \"" + DotCommand + "\" doesn't exist.");

                Firmware = (args[2] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(Firmware))
                    return Help();
                if (!File.Exists(Firmware))
                    return Error("Firmware \"" + Firmware + "\" doesn't exist.");

                // Pad or trunate dot command
                var dotBytes = File.ReadAllBytes(DotCommand);
                if (dotBytes.Length == Size)
                {
                    Console.WriteLine("Dot command is already exactly " + Size + " bytes.");
                }
                if (dotBytes.Length < Size)
                {
                    int oldLen = dotBytes.Length;
                    Console.WriteLine("Dot command is only " + oldLen + " bytes long");
                    var newDot = new byte[Size];
                    Array.Copy(dotBytes, newDot, oldLen);
                    Console.WriteLine("Padding dot command to " + Size + " bytes by appending " + (Size - oldLen) + " bytes");
                    dotBytes = newDot;
                }
                else
                {
                    int oldLen = dotBytes.Length;
                    Console.WriteLine("Dot command is " + oldLen + " bytes long");
                    dotBytes = dotBytes.Take(Size).ToArray();
                    Console.WriteLine("Truncating dot command to " + Size + " bytes");
                }

                // Append firmware
                var fwBytes = File.ReadAllBytes(Firmware);
                fwBytes[2] = Convert.ToByte((FlashParams & 0xff00) >> 8);
                fwBytes[3] = Convert.ToByte(FlashParams & 0xff);
                //File.WriteAllBytes(Firmware.Replace(".bin", "_calc.bin"), fwBytes);
                using (MD5 md5 = MD5.Create())
                {
                    byte[] bHash = md5.ComputeHash(fwBytes);
                    header.Md5 = BitConverter.ToString(bHash).Replace("-", "").ToLowerInvariant();
                    //Console.WriteLine("MD5 Hash: " + header.Md5 + " (" + header.Md5.Length + ")");
                }

                //File.WriteAllBytes(Firmware.Replace(".bin", "_comp.bin"), fwCompressed);

                var output = dotBytes.ToList();
                output.AddRange(header.Serialize(fwBytes));
                Console.WriteLine("Dot command is now " + output.Count + " bytes long");
                Console.WriteLine("Writing dot command");
                File.WriteAllBytes(DotCommand, output.ToArray());

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
        {
            Console.WriteLine("Usage:");
            Console.WriteLine("  AppendFW.exe Size DotCommandPathAndFile FirmwarePathAndFile [-i]");
            return 1;
        }
    }
}
