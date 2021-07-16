using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using ZLibNet;

namespace CompressAndHashFW
{
    class Program
    {
        public static bool Verbose;
        static bool Interactive;
        static string InputFile;
        static string OutputFile;
        static short FlashParams = 0;
        static byte[] InputBytes = new byte[0];
        static byte[] OutputBytes;
        static string md5String;

        static int Main(string[] args)
        {
            try
            {
                Verbose = args.Any(a => a == "-v");
                Interactive = args.Any(a => a == "-i");
                Log("Compressing ESP factory firmware and calculating MD5 hash...");
                if (Interactive)
                    Log("Running in interactive mode");
                Verbose = args.Any(a => a == "-v");
                if (Verbose)
                    Log("Running in verbose mode");

                // Flash Params
                string fp = (args.FirstOrDefault(a => a.StartsWith("-f=0x")) ?? "     ").Substring(5);
                short.TryParse(fp, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out FlashParams);
                Log("Flash params: 0x" + FlashParams.ToString("X4"));

                // Input file
                InputFile = (args[0] ?? "").Trim();
                if (string.IsNullOrWhiteSpace(InputFile))
                    return Help();
                if (!File.Exists(InputFile))
                    Error("Input file \"" + InputFile + "\" doesn't exist.");
                try
                {
                    InputBytes = File.ReadAllBytes(InputFile);
                }
                catch { }
                if (InputBytes == null || InputBytes.Length == 0)
                    return Error("Cannot open input file \"" + InputFile + "\".");
                Log("Input firmware: " + InputBytes.Length + " bytes (uncompressed)");
                if (InputBytes.Length < 0x100000) // 1MB
                {
                    var ib = InputBytes.ToList();
                    Pad(ib, 0x100000);
                    InputBytes = ib.ToArray();
                    Log("Padding uncompressed input firmware to: " + InputBytes.Length + " bytes");
                }    
                else
                    Log("Uncompressed input is already padded to 1MB or more");

                // Set flash params
                InputBytes[2] = Convert.ToByte((FlashParams & 0xff00) >> 8);
                InputBytes[3] = Convert.ToByte(FlashParams & 0xff);
                Log("Writing flash params at positions 2 (0x" + InputBytes[2].ToString("X2")
                    + ") and 3 (0x" + InputBytes[3].ToString("X2") + ")");

                // Calculate MD5 hash
                using (MD5 md5 = MD5.Create())
                {
                    var md5Bytes = md5.ComputeHash(InputBytes); // 16 bytes of binary, not hex string
                    md5String = BitConverter.ToString(md5Bytes).Replace("-", "").ToLowerInvariant();
                    Log("MD5 Hash: " + md5String);
                    StdOut(md5String); // This is the only output when not in Verbose mode!
                }

                // Compress
                OutputBytes = Compress(InputBytes);
                Log("Compressed firmware: " + OutputBytes.Length + " bytes");
                string dir = Path.GetDirectoryName(InputFile);
                OutputFile = Path.Combine(dir,Path.GetFileNameWithoutExtension(InputFile) + ".zfac");
                Log("Writing to " + OutputFile);
                File.WriteAllBytes(OutputFile, OutputBytes);

                return 0;
            }
            finally
            {
                if (Interactive)
                {
                    Log();
                    Log("Press any key to continue...");
                    Console.ReadKey();
                }
            }
        }

        public static void Log(string Msg = "")
        {
            if (Verbose)
                Console.WriteLine(Msg);
        }

        public static void StdOut(string Msg = "")
        {
            if (!Verbose)
                Console.WriteLine(Msg);
        }

        static int Error(string Msg)
        {
            Console.WriteLine(Msg ?? "");
            return 1;
        }

        static int Help()
        {   //                 12345678901234567890123456789012345678901234567890123456789012345678901234567890
            //Console.WriteLine("Usage:");
            //Console.WriteLine("  PackageFW.exe <DotCommandPathAndFile> <FirmwarePathAndFile> [f=<FlashParams>]\r\n"
            //                + "  [-v=<Version>] [-b=<BlockSize>] [-i]");
            return 1;
        }
        static void Pad(List<byte> Output, int Size)
        {
            if (Output.Count > Size)
                throw new InvalidDataException("Output is already larger than 0x" + Size.ToString("X2") + ".");
            Output.AddRange(Enumerable.Repeat(Convert.ToByte(0xff), Size - Output.Count));
        }

        static byte[] Compress(byte[] input)
        {
            using (MemoryStream inputStream = new MemoryStream(input))
            using (MemoryStream outputStream = new MemoryStream())
            {
                using (var compressor = new ZLibStream(outputStream, CompressionMode.Compress, CompressionLevel.Level9))
                {
                    inputStream.CopyTo(compressor);
                    compressor.Close();
                    return outputStream.ToArray();
                }
            }
        }
    }
}
