# Active Directory User Billing Collection Project

## Project Overview

This document outlines a comprehensive solution for collecting and tracking billable user data from multiple Active Directory environments across client networks. The system is designed to identify users in specific groups, categorize them as billable or non-billable based on predefined criteria, and store this information in a centralized PostgreSQL database hosted on Supabase.

## Business Requirements

1. Collect user information from multiple client Active Directory environments
2. Identify users in specific groups (RDSH, Horizon, workstation, app users)
3. Categorize users as billable or non-billable based on account status and attributes
4. Store historical data to track changes in billable user counts over time
5. Deploy solution across 100+ client Active Directory servers
6. Use NinjaRMM for scheduled execution of data collection
7. Track decreases in billable user counts for potential revenue impact analysis

## Technical Components

### 1. PowerShell Data Collection Script

The core data collection script performs the following functions:

- Queries Active Directory for groups matching specific patterns:
  - Groups containing "rdsh" or "horizon" in the name
  - Groups matching the pattern "r[0-9] users"
  - Groups starting with "app_"
  - Groups starting with "Workstation"
- Retrieves all members from these groups
- Categorizes each user as billable or non-billable based on:
  - Account enabled status (disabled accounts are non-billable)
  - Employee type attribute (employeeType = "core" are non-billable)
  - Username patterns matching admin/test/user/guest (non-billable, unless employeeType = "Cloud")
- Collects the computer name of the AD server (for client identification)
- Formats and posts data to both:
  - Original webhook endpoint (for backward compatibility)
  - Supabase PostgreSQL database (new centralized storage)

### 2. PostgreSQL Database Structure

The database consists of two primary tables:

**billing_data table:**
- Stores summary information for each collection run
- Contains client name, billable user count, non-billable user count, and collection date
- Includes audit columns for tracking record creation and updates

**billing_users table:**
- Stores individual user records for each collection run
- Links to the parent billing_data record
- Identifies each user as billable or non-billable
- Includes username and audit columns

Additional components:
- Custom data types for maintaining data integrity
- Indexes for optimizing query performance
- Triggers for automatic timestamp updating

### 3. Change Tracking Component

Functionality to detect and flag decreases in billable user counts:
- Comparison trigger that activates on new data insertion
- Dedicated billing_changes table for tracking significant changes
- Custom view for simplified analysis of billing trends
- Potential notification system for alerting on decrease events

## Implementation Details

### PowerShell Script

The PowerShell script is structured to:
1. Query AD groups and collect member information
2. Apply business rules to categorize users
3. Format data for both legacy webhook and Supabase database
4. Handle errors and provide appropriate logging
5. Execute without creating temporary files on client systems

Key considerations:
- Error handling for AD accounts not found
- Proper security protocol settings for TLS 1.2
- Unique user lists with proper sorting
- Efficient API communication with Supabase

### Database Schema

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
```

### Change Tracking Implementation

```sql
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

## Deployment Strategy

The solution can be deployed using multiple approaches:

1. **PowerShell Script with NinjaRMM**
   - Deploy PowerShell script to all client AD servers
   - Schedule execution via NinjaRMM
   - Configure direct API communication with Supabase

2. **.NET Application Option**
   - Convert PowerShell logic to C# console application
   - Deploy executable to all client AD servers
   - Schedule via NinjaRMM or internal Windows Task Scheduler
   - Benefits include improved performance and more secure credential handling

## Potential Enhancements

1. **Security Improvements**
   - Implement secure storage for API keys
   - Consider using client-specific API tokens
   - Add IP-based security rules in Supabase

2. **Monitoring & Alerting**
   - Set up automated alerts for billable user count decreases
   - Create dashboard for visualizing trends across clients
   - Implement notification system for collection failures

3. **Performance Optimization**
   - Batch API requests for inserting user records
   - Implement connection pooling for database operations
   - Add caching mechanisms for frequently accessed data

4. **Expanded Analytics**
   - Track user type changes over time
   - Identify patterns in billable/non-billable user distribution
   - Calculate revenue impact of user count changes

## Implementation Timeline

1. **Phase 1: Core Infrastructure (Week 1-2)**
   - Set up Supabase database with proper schema
   - Develop and test PowerShell script on sample AD
   - Implement basic data collection and storage

2. **Phase 2: Deployment & Monitoring (Week 3-4)**
   - Deploy solution to initial set of client ADs
   - Set up monitoring and validation processes
   - Refine script based on initial feedback

3. **Phase 3: Analytics & Reporting (Week 5-6)**
   - Implement change tracking functionality
   - Develop reporting dashboard for trend analysis
   - Set up alerting for significant changes

4. **Phase 4: Optimization & Scale (Week 7-8)**
   - Roll out to all 100+ client environments
   - Optimize performance for large-scale operation
   - Implement any identified enhancements

## Conclusion

This project provides a robust solution for tracking billable user data across multiple client Active Directory environments. By centralizing this data in a well-structured PostgreSQL database, the system enables effective monitoring of billable user counts and their changes over time. The solution is designed to be scalable, maintainable, and capable of providing valuable insights for business decision-making.
