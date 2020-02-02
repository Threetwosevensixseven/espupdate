using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace AppendFW
{
    class Program
    {
        static bool Interactive;
        static int PadSize;
        static string DotCommand;
        static string Firmware;

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("Appending NXESP formatted firmare to ESPUPDATE dot command...");
                Interactive = args.Any(a => a == "-i");
                if (Interactive)
                    Console.WriteLine("Running in interactive mode");
                if (args.Length < 3)
                    return Help();

                // Dot command file
                DotCommand = (args[0] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(DotCommand))
                    return Help();
                if (!File.Exists(DotCommand))
                    return Error("Dot command \"" + DotCommand + "\" doesn't exist.");

                // NXESP firmware file
                Firmware = (args[1] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(Firmware))
                    return Help();
                if (!File.Exists(Firmware))
                    return Error("Firmware file \"" + Firmware + "\" doesn't exist.");

                // Size
                int.TryParse(args[2], out PadSize);
                if (PadSize <= 0)
                    return Help();

                // Pad or trunate dot command
                var dotBytes = File.ReadAllBytes(DotCommand);
                if (dotBytes.Length == PadSize)
                {
                    Console.WriteLine("Dot command is already exactly " + PadSize + " bytes.");
                }
                if (dotBytes.Length < PadSize)
                {
                    int oldLen = dotBytes.Length;
                    Console.WriteLine("Dot command is only " + oldLen + " bytes long");
                    var newDot = new byte[PadSize];
                    Array.Copy(dotBytes, newDot, oldLen);
                    Console.WriteLine("Padding dot command to " + PadSize + " bytes by appending " + (PadSize - oldLen) + " bytes");
                    dotBytes = newDot;
                }
                else
                {
                    int oldLen = dotBytes.Length;
                    Console.WriteLine("Dot command is " + oldLen + " bytes long");
                    dotBytes = dotBytes.Take(PadSize).ToArray();
                    Console.WriteLine("Truncating dot command to " + PadSize + " bytes");
                }

                // Append firmware
                var outputFile = dotBytes.ToList();
                var fwBytes = File.ReadAllBytes(Firmware);
                outputFile.AddRange(fwBytes);
                Console.WriteLine("Dot command is now " + outputFile.Count + " bytes long");
                Console.WriteLine("Writing dot command");
                File.WriteAllBytes(DotCommand, outputFile.ToArray());

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
            Console.WriteLine("  AppendFW.exe <DotCommandFile> <NXESPFirmwareFile> <PadSize> [-i]");
            return 1;
        }
    }
}
