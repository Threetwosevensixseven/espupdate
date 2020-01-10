using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Text;

namespace UARTTest
{
    class Program
    {
        static void Main(string[] args)
        {
            var p = new SerialPort();
            p.PortName = "COM5";
            p.BaudRate = 115200;
            p.Parity = Parity.None;
            p.DataBits = 8;
            p.StopBits = StopBits.One;
            p.Open();
            var bytes = new List<byte>();
            for (int i = 0; i < 256; i++)
                bytes.Add(Convert.ToByte(i));
            //string s = Encoding.ASCII.GetString(bytes.ToArray(), 0, bytes.Count);
            //p.Write(s);
            p.Write(bytes.ToArray(), 0, bytes.Count);
            p.Close();
        }
    }
}
