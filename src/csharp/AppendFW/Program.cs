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
        static int Size;
        static string DotCommand;
        static string Firmware;

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
                Console.WriteLine("Appending firmware");
                var fwBytes = File.ReadAllBytes(Firmware);
                var output = dotBytes.ToList();
                output.AddRange(fwBytes);
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
