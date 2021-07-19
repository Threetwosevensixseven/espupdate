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
using ZLibNet;

namespace PackageFW.Data
{
    public class NxEspHeader
    {
        const string MAGIC = "NXESP";
        public bool PreCompressed { get; set; }
        public byte[] Md5 { get; set; }
        public string Version { get; set; }
        public short FlashParams { get; set; }
        public short DataBlockSize { get; set; }
        public byte HeaderBlockSize { get; set; }
        public List<NxEspHeaderBlock> Blocks { get; private set; }

        public byte[] Serialize(byte[] Uncompressed)
        {
            Blocks = new List<NxEspHeaderBlock>();
            var fwCompressed = Uncompressed;
            if (!PreCompressed)
                fwCompressed = Compress(Uncompressed);
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
            bs.AddRange(Md5);
            //bs.AddRange(ASCIIEncoding.ASCII.GetBytes(Md5)); // // 16 bytes of binary, not hex string
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

            if (Program.Verbose)
            {
                Console.WriteLine(new string('=', 80));
                Console.WriteLine("HEADER");
                Console.WriteLine(new string('-', 80));
                Console.WriteLine("MagicID: \"" + MAGIC + "\"");
                Console.WriteLine("VariableHeaderLen: " + ToHex(countedLen));
                Console.WriteLine("VersionLen: " + ToHex(Convert.ToByte(Version.Length)));
                Console.WriteLine("Version: \"" + Version + "\"");
                Console.WriteLine("FlashParams: " + ToHex(FlashParams));
                Console.WriteLine("MD5HashLen: " + ToHex(Convert.ToByte(Md5.Length)));
                Console.WriteLine("MD5Hash: " + ToHex(Md5));
                Console.WriteLine("DataBlockLen: " + ToHex(DataBlockSize));
                Console.WriteLine("CompressedDataLen: " + ToHex(fwCompressed.Length));
                Console.WriteLine("BlockSectionLen: " + ToHex(HeaderBlockSize));
                Console.WriteLine("BlockSectionCount: " + ToHex(Convert.ToInt16(Blocks.Count)));
                Console.WriteLine("CompressedDataLenStrLen: " + ToHex(Convert.ToByte(csize.Length)));
                Console.WriteLine("DataSectionLenStr: \"" + csize + "\"");
                Console.WriteLine(new string('-', 80));
                Console.WriteLine("HEADER BLOCKS");
                Console.WriteLine(new string('-', 80));
                short count = 0;
                foreach (var block in Blocks)
                    Console.WriteLine(block.LogVerbose(this, count++));
                Console.WriteLine(new string('=', 80));
            }

            // Add compressed data
            Console.WriteLine("Appending header: " + bs.Count + " bytes");
            Console.WriteLine("Appending firmware: " + fwCompressed.Length + " bytes");
            bs.AddRange(fwCompressed);
            return bs.ToArray();
        }

        public int OffsetLen
        {
            get
            {
                return (DataBlockSize * (Blocks.Count - 1)).ToString("X2").Length;
            }
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

        public string ToHex(int Value, bool Prefix = true)
        {
            return (Prefix ? "0x" : "") 
                + Value.ToString("X2").PadLeft(8, '0');
        }

        public string ToHex(short Value, bool Prefix = true)
        {
            return (Prefix ? "0x" : "") 
                + Value.ToString("X2").PadLeft(4, '0');
        }

        public string ToHex(byte Value, bool Prefix = true)
        {
            return (Prefix ? "0x" : "") 
                + Value.ToString("X2").PadLeft(2, '0');
        }

        public string ToHex(byte[] Value, bool Prefix = false)
        {
            string rv = Prefix ? "0x" : "";
            foreach (byte b in Value)
                rv += b.ToString("X2").PadLeft(2, '0');
            return rv;
        }
    }
}
