This Python script is designed to send automated emails through an SMTP
server, supporting both internal enterprise mail relays and external
email providers.

## Its primary purpose is to:

-   🚀 Validate email relay configuration (e.g., your internal SMTP like
    10.10.10.10)\
-   🔔 Enable automated notifications from systems such as Jenkins,
    scripts, or monitoring tools\
-   🔄 Provide a flexible email-sending mechanism that adapts to
    different environments:
    -   Internal relay (no authentication, no TLS)\
    -   Secure providers (TLS + authentication)

```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# =========================
# CONFIGURATION
# =========================

provider = "relay"  # Options: "gmail", "office365", "relay"

email_user = ""
email_password = ""  # Keep empty if relay does not require authentication

to_email = ""
subject = "Email Configuration Test"
body = "This email was sent successfully using the selected provider."

# SMTP configurations
smtp_settings = {
    "gmail": {
        "server": "smtp.gmail.com",
        "port": 587,
        "use_tls": True,
        "use_auth": True
    },
    "office365": {
        "server": "smtp.office365.com",  # real O365 SMTP
        "port": 587,
        "use_tls": True,
        "use_auth": True
    },
    "relay": {
        "server": "10.10.10.10",  # your internal relay
        "port": 25,
        "use_tls": False,
        "use_auth": False
    }
}

# =========================
# VALIDATION
# =========================

if provider not in smtp_settings:
    raise ValueError(f"Invalid provider: {provider}")

config = smtp_settings[provider]
smtp_server = config["server"]
smtp_port = config["port"]

# =========================
# CREATE EMAIL
# =========================

msg = MIMEMultipart()
msg['From'] = email_user
msg['To'] = to_email
msg['Subject'] = subject

msg.attach(MIMEText(body, 'plain'))

# =========================
# SEND EMAIL
# =========================

try:
    server = smtplib.SMTP(smtp_server, smtp_port, timeout=10)
    server.ehlo()

    # Enable TLS if supported and required
    if config["use_tls"]:
        if server.has_extn('STARTTLS'):
            server.starttls()
            server.ehlo()
        else:
            raise RuntimeError("Server does not support STARTTLS but TLS is required.")

    # Authenticate if required
    if config["use_auth"]:
        if not email_password:
            raise ValueError("Password required for authentication but not provided.")
        server.login(email_user, email_password)

    # Send email
    server.sendmail(email_user, to_email, msg.as_string())
    server.quit()

    print(f"[SUCCESS] Email sent using {provider.upper()} via {smtp_server}:{smtp_port}")

except Exception as e:
    print(f"[ERROR] Failed to send email using {provider.upper()}: {e}")
```
