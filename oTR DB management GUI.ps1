# Load Windows Forms assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "osu! Tournament Rating DB Manager"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Container ID Input
$containerLabel = New-Object System.Windows.Forms.Label
$containerLabel.Location = New-Object System.Drawing.Point(20, 20)
$containerLabel.Size = New-Object System.Drawing.Size(100, 20)
$containerLabel.Text = "Container ID:"
$form.Controls.Add($containerLabel)

$containerInput = New-Object System.Windows.Forms.TextBox
$containerInput.Location = New-Object System.Drawing.Point(120, 20)
$containerInput.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($containerInput)

# Container Info Display
$containerInfoLabel = New-Object System.Windows.Forms.Label
$containerInfoLabel.Location = New-Object System.Drawing.Point(20, 50)
$containerInfoLabel.Size = New-Object System.Drawing.Size(400, 20)
$containerInfoLabel.Text = "Container Name: Not selected"
$form.Controls.Add($containerInfoLabel)

# Status TextBox
$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(20, 280)
$statusBox.Size = New-Object System.Drawing.Size(540, 150)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$form.Controls.Add($statusBox)

# Backup GroupBox
$backupGroup = New-Object System.Windows.Forms.GroupBox
$backupGroup.Location = New-Object System.Drawing.Point(20, 80)
$backupGroup.Size = New-Object System.Drawing.Size(540, 80)
$backupGroup.Text = "Backup"
$form.Controls.Add($backupGroup)

$backupPathBox = New-Object System.Windows.Forms.TextBox
$backupPathBox.Location = New-Object System.Drawing.Point(10, 20)
$backupPathBox.Size = New-Object System.Drawing.Size(400, 20)
$backupPathBox.Text = [Environment]::GetFolderPath("MyDocuments") + "\dump.gz"
$backupGroup.Controls.Add($backupPathBox)

$backupButton = New-Object System.Windows.Forms.Button
$backupButton.Location = New-Object System.Drawing.Point(420, 20)
$backupButton.Size = New-Object System.Drawing.Size(100, 23)
$backupButton.Text = "Backup"
$backupGroup.Controls.Add($backupButton)

# Restore GroupBox
$restoreGroup = New-Object System.Windows.Forms.GroupBox
$restoreGroup.Location = New-Object System.Drawing.Point(20, 170)
$restoreGroup.Size = New-Object System.Drawing.Size(540, 80)
$restoreGroup.Text = "Restore"
$form.Controls.Add($restoreGroup)

$restorePathBox = New-Object System.Windows.Forms.TextBox
$restorePathBox.Location = New-Object System.Drawing.Point(10, 20)
$restorePathBox.Size = New-Object System.Drawing.Size(400, 20)
$restoreGroup.Controls.Add($restorePathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(420, 20)
$browseButton.Size = New-Object System.Drawing.Size(100, 23)
$browseButton.Text = "Browse"
$restoreGroup.Controls.Add($browseButton)

# Operation Buttons
$dropCreateButton = New-Object System.Windows.Forms.Button
$dropCreateButton.Location = New-Object System.Drawing.Point(20, 440)
$dropCreateButton.Size = New-Object System.Drawing.Size(150, 23)
$dropCreateButton.Text = "Drop and Create Schema"
$form.Controls.Add($dropCreateButton)

# Function to validate container
function Test-ContainerExists {
    param (
        [string]$containerId
    )
    if ([string]::IsNullOrEmpty($containerId)) { return $false }
    $containerExists = docker ps -q --filter "id=$containerId"
    return ![string]::IsNullOrEmpty($containerExists)
}

# Function to get container name
function Get-ContainerName {
    param (
        [string]$containerId
    )
    return (docker inspect --format='{{.Name}}' $containerId).TrimStart('/')
}

# Function to log status
function Write-Status {
    param (
        [string]$message
    )
    $statusBox.AppendText("$(Get-Date -Format 'HH:mm:ss'): $message`r`n")
    $statusBox.ScrollToCaret()
}

# Container ID validation event
$containerInput.Add_TextChanged({
    if (Test-ContainerExists $containerInput.Text) {
        $containerName = Get-ContainerName $containerInput.Text
        $containerInfoLabel.Text = "Container Name: $containerName"
        $containerInfoLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $containerInfoLabel.Text = "Container not found or not running"
        $containerInfoLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Browse button click event
$browseButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "GZip files (*.gz)|*.gz|All files (*.*)|*.*"
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    if ($openFileDialog.ShowDialog() -eq 'OK') {
        $restorePathBox.Text = $openFileDialog.FileName
    }
})

# Backup button click event
$backupButton.Add_Click({
    if (-not (Test-ContainerExists $containerInput.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a valid container ID", "Error")
        return
    }
    
    try {
        Write-Status "Starting backup..."
        docker exec $containerInput.Text pg_dump -c -U postgres -d postgres | wsl gzip > $backupPathBox.Text
        Write-Status "Backup completed successfully!"
    } catch {
        Write-Status "Error during backup: $_"
    }
})

# Drop and Create Schema button click event
$dropCreateButton.Add_Click({
    if (-not (Test-ContainerExists $containerInput.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a valid container ID", "Error")
        return
    }

    try {
        Write-Status "Dropping public schema..."
        docker exec -it $containerInput.Text psql -U postgres -c "DROP SCHEMA public CASCADE;" -d postgres
        
        Write-Status "Creating public schema..."
        docker exec -it $containerInput.Text psql -U postgres -c "CREATE SCHEMA public;" -d postgres
        
        Write-Status "Schema operations completed successfully!"
        
        # Ask if user wants to restore
        $restoreChoice = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to restore from backup now?", 
            "Restore Database",
            [System.Windows.Forms.MessageBoxButtons]::YesNo)
            
        if ($restoreChoice -eq 'Yes' -and $restorePathBox.Text) {
            Write-Status "Starting restore from $($restorePathBox.Text)..."
            wsl gunzip -c $restorePathBox.Text | docker exec -i $containerInput.Text psql -U postgres -d postgres
            Write-Status "Restore completed successfully!"
        }
    } catch {
        Write-Status "Error: $_"
    }
})

# Show the form
$form.ShowDialog()
