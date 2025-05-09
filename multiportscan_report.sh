#!/bin/bash
set -x
# List of servers
servers=("")  # ← Add your IPs/hostnames here

# Email recipient
recipient=""

# Temp files
report_txt="/tmp/portscan-report.txt"
report_ps="/tmp/portscan-report.ps"
report_pdf="/tmp/portscan-report.pdf"
encoded_pdf="/tmp/portscan-report.b64"
email_file="/tmp/email.txt"
boundary="ZZ_$(date +%s)_ZZ"

# Clean up old files
rm -f "$report_txt" "$report_ps" "$report_pdf" "$encoded_pdf" "$email_file"

# Create report header
echo "Port Scan Report - $(date)" > "$report_txt"
echo "==============================" >> "$report_txt"

# Run full scan for each server
for server in "${servers[@]}"; do
  echo "Scanning all ports on $server..." | tee -a "$report_txt"
  scan_result=$(nmap -Pn -p- "$server" 2>&1)

  if [[ -z "$scan_result" ]]; then
    echo "⚠️ No output received from $server" | tee -a "$report_txt"
  else
    echo "$scan_result" >> "$report_txt"
  fi

  echo -e "---------------------------------\n" >> "$report_txt"
done

# Verify report file
if [ ! -s "$report_txt" ]; then
  echo "❌ Error: Empty report file. Exiting."
  exit 1
fi

# Convert to PDF
enscript "$report_txt" -o "$report_ps"
ps2pdf "$report_ps" "$report_pdf"

if [ ! -s "$report_pdf" ]; then
  echo "❌ Error: PDF generation failed."
  exit 1
fi

# Encode PDF
base64 "$report_pdf" > "$encoded_pdf"

# Compose email with attachment
{
  echo "To: $recipient"
  echo "Subject: Full Port Scan Report (PDF)"
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/mixed; boundary=\"$boundary\""
  echo
  echo "--$boundary"
  echo "Content-Type: text/plain; charset=UTF-8"
  echo
  echo "Hello,"
  echo
  echo "Attached is the full port scan report in PDF format."
  echo
  echo "--$boundary"
  echo "Content-Type: application/pdf; name=\"portscan-report.pdf\""
  echo "Content-Disposition: attachment; filename=\"portscan-report.pdf\""
  echo "Content-Transfer-Encoding: base64"
  echo
  cat "$encoded_pdf"
  echo "--$boundary--"
} > "$email_file"

# Send via msmtp
cat "$email_file" | msmtp "$recipient"

# Clean up
rm "$report_txt" "$report_ps" "$report_pdf" "$encoded_pdf" "$email_file"

echo "✅ Full port scan complete. PDF report sent to $recipient via msmtp."
