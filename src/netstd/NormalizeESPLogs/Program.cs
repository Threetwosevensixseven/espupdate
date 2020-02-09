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
using System.Configuration;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace NormalizeESPLogs
{
    class Program
    {
        static bool Interactive;
        static bool Force;

        static void Main(string[] args)
        {
            try
            {
                Interactive = args.Any(a => a == "-i");
                if (Interactive)
                    Console.WriteLine("Running in interactive mode");

                Force = args.Any(a => a == "-f");
                if (Force)
                    Console.WriteLine("Forcing normalize of every file");

                string logDir = (ConfigurationManager.AppSettings["LogDir"] ?? "").Trim();
                string logPattern = (ConfigurationManager.AppSettings["LogPattern"] ?? "").Trim();
                var files = Directory.GetFiles(logDir, logPattern);
                var r = new Regex(@"^\s*[\[]\d{2}/\d{2}/\d{4}\s\d{2}:\d{2}:\d{2}[\]]\s(?<Action>(?:Written|Read)\sdata)\s\(COM\d+\)\s*$");
                foreach (string file in files)
                {
                    var fn = Path.GetFileName(file);
                    Console.Write("Normalizing " + fn + "...");
                    var inLines = File.ReadAllLines(file);
                    var outLines = new List<string>();
                    bool changed = false;
                    foreach (var line in inLines)
                    {
                        var m = r.Match(line);
                        if (!m.Success || !m.Groups["Action"].Success)
                            outLines.Add(line);
                        else
                        {
                            outLines.Add(m.Groups["Action"].Value);
                            changed = true;
                        }
                    }
                    if (changed || Force)
                    {
                        File.WriteAllLines(file, outLines, Encoding.ASCII);
                        Console.WriteLine(" DONE");
                    }
                    else
                        Console.WriteLine(" SKIPPED");
                }
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
    }
}
