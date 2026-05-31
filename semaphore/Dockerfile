FROM semaphoreui/semaphore:latest

USER root

# PowerShell 7 auf Alpine installieren
RUN apk add --no-cache powershell && \
    ln -s /usr/bin/pwsh /usr/local/bin/powershell

USER semaphore
