using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ZLibNet;

namespace AppendFW
{
    public class NxEspHeader
    {
        const string MAGIC = "NXESP";

        public string Md5 { get; set; }
        public string Version { get; set; }
        public short FlashParams { get; set; }

        public byte[] Serialize(byte[] Uncompressed)
        {
            var fwCompressed = Compress(Uncompressed);
            var bs = new List<byte>();
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(MAGIC));
            int headerLen = 0;
            bs.Add(BitConverter.GetBytes(headerLen));
            int RemoveLen = bs.Count;
            bs.Add(Convert.ToByte(Version.Length));
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(Version));
            bs.Add(BitConverter.GetBytes(FlashParams));
            bs.Add(Convert.ToByte(Md5.Length));
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(Md5));      
            bs.Add(BitConverter.GetBytes(fwCompressed.Length));
            Console.WriteLine("Appending header: " + MAGIC + " " + Version + " " + FlashParams.ToString("X4") 
                + " " + Md5 + " (" + bs.Count + " bytes)");
            headerLen = bs.Count - RemoveLen;
            var headerLenB = BitConverter.GetBytes(headerLen);
            bs[5] = headerLenB[0];
            bs[6] = headerLenB[1];
            bs[7] = headerLenB[2];
            bs[8] = headerLenB[3];
            Console.WriteLine("Appending firmware (" + fwCompressed.Length + " bytes)");
            bs.AddRange(fwCompressed);
            return bs.ToArray();
        }

        private byte[] Compress(byte[] input)
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
