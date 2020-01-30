using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AppendFW.Data
{
    public class NxEspHeaderBlock
    {
        public short Size { get; set; }
        public int Offset { get; set; }
        public byte Percent { get; set; }

        public List<byte> Serialize(NxEspHeader Parent)
        {
            // Don't use BitConverter to serialise numerics because we always want little-endian
            var bs = new List<byte>();
            bs.Add(Convert.ToByte(Size % 256));
            bs.Add(Convert.ToByte(Size / 256));
            string offset = Offset.ToString("X2").PadLeft(8, '0');
            string percent = Percent.ToString();
            string desc = (offset + " (" + percent + "%)").PadRight(15);
            bs.AddRange(ASCIIEncoding.ASCII.GetBytes(desc));
            bs.Add(0); // Null termination
            if (Parent.HeaderBlockSize <= 0)
                Parent.HeaderBlockSize = Convert.ToByte(bs.Count);
            else if (Parent.HeaderBlockSize != bs.Count)
                throw new Exception("Header blocks cannot be different sizes.");
            return bs; // Should be always 18 bytes
        }
    }
}
