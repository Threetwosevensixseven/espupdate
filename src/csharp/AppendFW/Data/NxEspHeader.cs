using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ZLibNet;

namespace AppendFW.Data
{
    public class NxEspHeader
    {
        const string MAGIC = "NXESP";
        public string Md5 { get; set; }
        public string Version { get; set; }
        public short FlashParams { get; set; }
        public short DataBlockSize { get; set; }
        public byte HeaderBlockSize { get; set; }
        public List<NxEspHeaderBlock> Blocks { get; private set; }

        public byte[] Serialize(byte[] Uncompressed)
        {
            Blocks = new List<NxEspHeaderBlock>();
            var fwCompressed = Compress(Uncompressed);
            int blockCount = Convert.ToInt32(Math.Ceiling(Convert.ToDouble(fwCompressed.Length) / DataBlockSize));
            double cumSize = 0;
            for (int i = 0; i < blockCount; i++)
            {
                var block = new NxEspHeaderBlock();
                Blocks.Add(block);
                block.Offset = i * DataBlockSize;
                if (i == blockCount - 1)
                    block.Size = Convert.ToInt16(fwCompressed.Length - ((blockCount - 1) * DataBlockSize));
                else
                    block.Size = DataBlockSize;
                cumSize += block.Size;
                block.Percent = Convert.ToByte(Math.Round(cumSize * 100 / fwCompressed.Length, 0));
            }

            var blockBytes = new List<Byte>();
            foreach (var block in Blocks)
                blockBytes.AddRange(block.Serialize(this));

            // Add fixed part of header (7 bytes)
            var bs = new List<byte>();
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(MAGIC));
            short countedLen = 0;
            bs.Add(BitConverter.GetBytes(countedLen));
            int fixedLen = bs.Count;

            // Add counted part of header
            bs.Add(Convert.ToByte(Version.Length));
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(Version));
            bs.Add(BitConverter.GetBytes(FlashParams));
            bs.Add(Convert.ToByte(Md5.Length));
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(Md5));
            bs.Add(BitConverter.GetBytes(DataBlockSize));
            bs.Add(BitConverter.GetBytes(fwCompressed.Length));
            bs.Add(HeaderBlockSize);
            bs.Add(BitConverter.GetBytes(Convert.ToInt16(Blocks.Count)));
            string csize = fwCompressed.Length.ToString();
            bs.Add(Convert.ToByte(csize.Length));
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(csize));
            bs.AddRange(blockBytes);
            countedLen = Convert.ToInt16(bs.Count - fixedLen);
            var countedLenB = BitConverter.GetBytes(countedLen);
            bs[5] = countedLenB[0];
            bs[6] = countedLenB[1];

            // Add compressed data
            Console.WriteLine("Appending header: " + MAGIC + " " + Version + " " + FlashParams.ToString("X4")
                + " " + Md5 + " (" + bs.Count + " bytes)");
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

        public int OffsetLen
        {
            get
            {
                return (DataBlockSize * (Blocks.Count - 1)).ToString("X2").Length;
            }
        }
    }
}
