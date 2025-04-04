# ADC-Billing

A comprehensive solution for collecting and tracking billable Active Directory user data across multiple client environments.

## Project Overview

This system identifies users in specific Active Directory groups, categorizes them as billable or non-billable based on predefined criteria, and stores this information in a centralized PostgreSQL database hosted on Supabase. The solution enables effective monitoring of billable user counts and their changes over time.

## Features

- **User Identification**: Queries AD for users in specific groups (RDSH, Horizon, workstation, app users)
- **Smart Categorization**: Automatically identifies billable vs. non-billable users based on:
  - Account status (enabled/disabled)
  - Employee type attribute
  - Username patterns
- **Data Collection**: Gathers user information from multiple client AD environments
- **Centralized Storage**: Stores data in a PostgreSQL database on Supabase
- **Historical Tracking**: Maintains records of user counts over time
- **Change Detection**: Identifies decreases in billable user counts
- **Comprehensive Reporting**: Provides insights for business decision-making

## Components

### PowerShell Scripts

- **adc-get-billing-sync.ps1** / **billing-gather-sync.ps1**: 
  - Core script that collects user data from Active Directory
  - Categorizes users as billable or non-billable
  - Formats and sends data to the database

### Database Structure

The PostgreSQL database consists of three main tables:

- **billing_data**: Stores summary information for each collection run
- **billing_users**: Records individual user details for each collection run
- **billing_changes**: Tracks significant changes in billable user counts

## Installation

1. Clone this repository to your local environment

```bash
git clone https://github.com/yourusername/ADC-Billing.git
cd ADC-Billing
```

2. Update the Supabase configuration in the PowerShell script:

```powershell
# Supabase configuration
$supabaseUrl = "https://your-project-id.supabase.co"
$supabaseKey = "your-supabase-api-key"
```

3. Set up the PostgreSQL database schema on Supabase:

```sql
-- Main billing data table
CREATE TABLE billing_data (
    id SERIAL PRIMARY KEY,
    client_name VARCHAR(255) NOT NULL,
    billable_user_count INTEGER NOT NULL,
    non_billable_user_count INTEGER NOT NULL,
    collection_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User details table
CREATE TABLE billing_users (
    id SERIAL PRIMARY KEY,
    billing_id INTEGER REFERENCES billing_data(id) ON DELETE CASCADE,
    username VARCHAR(255) NOT NULL,
    user_type user_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(billing_id, username)
);

-- Create user_type enum
CREATE TYPE user_type AS ENUM ('billable', 'non_billable');

-- Change tracking table
CREATE TABLE billing_changes (
    id SERIAL PRIMARY KEY,
    client_name VARCHAR(255) NOT NULL,
    previous_count INTEGER NOT NULL,
    new_count INTEGER NOT NULL,
    difference INTEGER NOT NULL,
    previous_date TIMESTAMP WITH TIME ZONE NOT NULL,
    new_date TIMESTAMP WITH TIME ZONE NOT NULL,
    change_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Deployment

### Option 1: PowerShell Script with NinjaRMM

1. Deploy the PowerShell script to all client AD servers
2. Schedule execution via NinjaRMM
3. Configure direct API communication with Supabase

### Option 2: .NET Application

1. Convert PowerShell logic to C# console application
2. Deploy executable to all client AD servers
3. Schedule via NinjaRMM or internal Windows Task Scheduler

## Usage

The script can be executed manually or scheduled to run automatically:

```powershell
# Manual execution
.\adc-get-billing-sync.ps1
```

When executed, the script will:
1. Query AD for specific groups and their members
2. Categorize users as billable or non-billable
3. Send data to both the legacy webhook and Supabase
4. Output a summary of the operation

## Requirements

- Windows Server with Active Directory
- PowerShell 5.1 or higher
- Active Directory PowerShell module
- Internet connectivity for API communication
- Proper permissions to query AD groups and users

## Security Considerations

- Secure storage for API keys
- Consider using client-specific API tokens
- Implement IP-based security rules in Supabase
- Use service accounts with minimal required permissions

## Future Enhancements

- Batch API requests for better performance
- Implement connection pooling for database operations
- Add caching mechanisms for frequently accessed data
- Develop dashboard for visualizing trends across clients
- Set up automated alerts for billable user count decreases
- Calculate revenue impact of user count changes

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Active Directory PowerShell module team
- Supabase for the database platform
- NinjaRMM for deployment automation
