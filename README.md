# VPS Configuration Management

This repository contains configuration files for a VPS server, primarily focused on Nginx configurations. A GitHub Actions workflow automatically deploys these configurations to the VPS when changes are pushed to the main branch.

## Repository Structure

- `nginx/` - Contains Nginx configuration files
  - `nginx.conf` - Main Nginx configuration file
  - `sites-available/` - Contains individual site configurations

## GitHub Actions Workflow

The repository includes a GitHub Actions workflow that automatically deploys configuration changes to your VPS server.

### How It Works

1. When you push changes to the `vps` branch, the workflow is triggered
2. The workflow connects to your VPS using SSH
3. It copies the configuration files to a temporary directory on your VPS
4. It uses sudo to move the files to their final locations in /etc/nginx/
5. It creates symbolic links for site configurations if they don't exist
6. It tests the Nginx configuration and reloads the service

### Required GitHub Secrets and Variables

The workflow requires the following GitHub secrets and variables to be set up:

- **Secret**: `VPS_SSH_KEY` - The private SSH key for connecting to your VPS
- **Secret**: `VPS_USER_PASSWORD` - The sudo password for the VPS user
- **Variable**: `VPS_HOST` - The hostname or IP address of your VPS
- **Variable**: `VPS_USERNAME` - The username for SSH connection to your VPS

**Important**: The user specified in `VPS_USERNAME` must have sudo privileges on the VPS to modify Nginx configuration files in system directories. The `VPS_USER_PASSWORD` is used to execute sudo commands on the VPS.

### Setting Up GitHub Secrets and Variables

1. Go to your GitHub repository
2. Click on "Settings" > "Secrets and variables" > "Actions"
3. Add the required secrets and variables:
   - To add a secret, click "New repository secret", enter the name (e.g., `VPS_SSH_KEY`) and value
   - To add a variable, click on the "Variables" tab, then "New repository variable", enter the name (e.g., `VPS_HOST`) and value

## Making Changes

1. Clone the repository to your local machine
2. Make changes to the configuration files
3. Commit and push your changes to the main branch
4. The GitHub Actions workflow will automatically deploy your changes to the VPS

## Troubleshooting

If the deployment fails, check the following:

1. Verify that all required secrets and variables are correctly set up in GitHub
2. Ensure the SSH key has the necessary permissions on the VPS
3. Confirm that the VPS user has sudo privileges
4. Verify that the VPS_USER_PASSWORD is correct if sudo requires a password
5. Check that the paths in the workflow file match the actual paths on your VPS
6. Review the GitHub Actions logs for specific error messages

### Common Errors

- **"Permission denied" errors**: The VPS user doesn't have sudo access or the file permissions are too restrictive.
- **"a terminal is required to read the password"**: This occurs when sudo requires a password but can't prompt for it in a non-interactive session. The workflow now uses `echo '${{ secrets.VPS_USER_PASSWORD }}' | sudo -S` to provide the password via standard input.
- **"a password is required"**: The sudo password is incorrect or not provided. Verify that the VPS_USER_PASSWORD secret is set correctly in GitHub.
- **"user directive is not allowed here in /etc/nginx/sites-enabled/nginx.conf"**: This error occurs when the main nginx.conf file (which contains the "user" directive) is incorrectly symlinked into the sites-enabled directory. The workflow now uses separate directories for the main configuration and site configurations to prevent this issue.

## Security Considerations

- The SSH key should have the minimum necessary permissions on the VPS
- Consider using a dedicated user for deployments
- Storing the sudo password in GitHub Secrets is convenient but has security implications
- For enhanced security, configure sudo access for the deployment user with NOPASSWD for specific commands:
  ```
  # Example sudoers file for nginx deployments
  deployuser ALL=(ALL) NOPASSWD: /bin/mkdir -p /etc/nginx/*, /bin/cp * /etc/nginx/*, /bin/ln -sf /etc/nginx/*, /usr/sbin/nginx -t, /bin/systemctl reload nginx
  ```
- If you use the NOPASSWD approach above, you can remove the VPS_USER_PASSWORD secret and modify the workflow to not use the `-S` option with sudo
- Regularly rotate SSH keys and passwords for enhanced security
- Consider using a password manager or secrets vault for managing sensitive credentials