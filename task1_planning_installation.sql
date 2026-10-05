-- =============================================================
-- Task 1: DBMS Planning and Installation
-- OS selection, hardware requirements, PostgreSQL configuration
-- =============================================================

-- =============================================================
-- Part 1: OPERATING SYSTEM SELECTION FOR PRODUCTION DBMS
-- =============================================================

/*
WHY LINUX (specifically Ubuntu 22.04 LTS or Red Hat Enterprise Linux 8/9):

1. PERFORMANCE & STABILITY
   - Linux kernel is highly optimized for database workloads
   - Efficient memory management (vm.swappiness tuning, huge pages)
   - Superior I/O scheduling (CFQ, BFQ, deadline schedulers)
   - Lower latency for disk and network operations
   - Proven on thousands of production PostgreSQL installations

2. COST EFFICIENCY
   - Open source: no licensing fees
   - Reduced operational costs compared to Windows/commercial UNIX
   - Large ecosystem of free tools (Prometheus, Grafana, pgAdmin, etc.)

3. SECURITY & COMPLIANCE
   - Linux provides mandatory access control (AppArmor, SELinux)
   - Security updates released quickly by community
   - Audit logging capabilities (auditd)
   - Supports FIPS compliance (for regulatory environments)
   - Source code transparency for security review

4. RESOURCE EFFICIENCY
   - Lightweight footprint (smaller memory/disk overhead)
   - Scales from small VMs to massive distributed systems
   - Excellent virtualization support (KVM, Xen, Hyper-V)
   - Container-native (Docker, Kubernetes integration)

5. TOOLING & ECOSYSTEM
   - PostgreSQL development occurs on Linux (native environment)
   - Best monitoring tools designed for Linux (CloudWatch, New Relic, Datadog)
   - Large community support and documentation
   - Easy integration with DevOps/CI-CD pipelines

6. SPECIFIC RECOMMENDATION: Ubuntu 22.04 LTS or RHEL 8/9
   - Ubuntu 22.04 LTS: 5-year support, modern tooling, ease of use
   - RHEL 8/9: Enterprise support, stability, compliance certifications
   - CentOS Stream: Free alternative to RHEL
   
PRODUCTION SETUP ASSUMPTIONS (for calculations below):
- E-commerce platform (from schema.sql)
- Expected 200 concurrent users (peak traffic)
- ~500 GB active working set
- 5,000 requests/second at peak
- 99.9% uptime SLA
- Data retention: 1 year for historical data, 90 days for audit logs
*/

-- =============================================================
-- Part 2: HARDWARE REQUIREMENTS CALCULATION
-- =============================================================

/*
ESTIMATED WORKLOAD:
- 200 concurrent connections (peak)
- ~5,000 transactions per second
- Read/Write ratio: 80% reads, 20% writes
- Average query duration: 50ms (typical OLTP)

CPU CORES:
  Formula: Max(connections/4, transactions_per_sec/100, cores_for_maintenance)
  
  - Concurrent connections factor: 200 / 4 = 50 cores (conservative)
  - Throughput factor: 5000 / 100 = 50 cores (PostgreSQL CPU usage)
  - Maintenance overhead: +2 cores (VACUUM, ANALYZE, backups)
  
  RECOMMENDATION: 16 cores (4-socket CPU or 2x8-core)
  RATIONALE:
    - Over-provisioned by 30% for headroom
    - Allows CPU cache efficiency (modern CPUs have 8-16 MB L3 cache)
    - Leaves room for operating system and monitoring agents
  
  COST-OPTIMIZED ALTERNATIVE: 8 cores (sufficient for 100 concurrent users)
  HIGH-PERFORMANCE OPTION: 32+ cores (for analytical workloads or >1000 concurrent)

RAM REQUIREMENTS:
  Formula: shared_buffers(25% RAM) + OS(2-4GB) + working_set(dependent on queries)
  
  Calculation:
  - Working set estimate: ~500 GB active data (from schema assumptions)
  - PostgreSQL buffer pool efficiency: typically 90-95%
  - Actual working set in memory: min(active_data, available_ram)
  - Shared buffers guideline: 25% of total RAM (max 40%)
  - Connection overhead: ~10 MB per connection
  
  For 200 concurrent connections:
  - Connection overhead: 200 × 10 MB = 2 GB
  - OS footprint: 3 GB
  - Working set cache: ~128 GB (minimum to avoid excessive disk I/O)
  - Shared buffers (25%): If total 256 GB, then shared_buffers = 64 GB
  
  RECOMMENDATION: 256 GB RAM
  RATIONALE:
    - Shared buffers: 64 GB (25%)
    - OS kernel cache: 150 GB (can be managed by kernel)
    - Connection buffers & overhead: 2-3 GB
    - Application memory, monitoring: 20-30 GB
    - Headroom: 20-40 GB
  
  COST-OPTIMIZED ALTERNATIVE: 128 GB RAM (for smaller databases <100 GB)
  HIGH-PERFORMANCE OPTION: 512+ GB RAM (for large working sets or data warehouse)

DISK SUBSYSTEM:
  
  Type: NVMe SSD (PCIe 4.0 minimum)
  Rationale:
    - Sequential throughput: >3500 MB/s (vs HDD ~100 MB/s)
    - Random IOPS: >200,000 (vs HDD ~1,000)
    - Latency: <100 microseconds (vs HDD >10ms)
    - Better for write-heavy audit logs and transaction journals
  
  IOPS Calculation:
    Formula: baseline_iops + working_set_factor + safety_margin
    
    - Baseline OLTP: 5000 transactions/sec × 2 = 10,000 IOPS
    - Write amplification (WAL, indexes): 10,000 × 1.5 = 15,000 IOPS
    - Cache misses (worst case): ×2 = 30,000 IOPS
    - Safety margin (50%): 30,000 × 1.5 = 45,000 IOPS
  
  NVMe SSD Performance:
    - Consumer grade (Samsung 990 Pro): ~700,000 IOPS
    - Enterprise grade (Intel Optane, Toshiba XG7): ~1,000,000+ IOPS
    - Safely handles 45,000 IOPS with <1% utilization
  
  RECOMMENDATION:
    - Primary data disk: 2× NVMe SSD 2TB (RAID 1 for redundancy)
    - Capacity: 2× 2TB = 4TB total (leaves room for growth, backups)
    - WAL journal: Separate 1TB NVMe SSD (RAID 1)
    - Total: 3× NVMe drives in RAID configurations
    - Target: 50,000 IOPS sustained capability
  
  COST-OPTIMIZED ALTERNATIVE: 
    - Single NVMe 1TB + HDD backup
    - Acceptable for dev/test only
  
  HIGH-PERFORMANCE OPTION:
    - 4× NVMe in RAID 10 (better write performance)
    - Separate WAL on dedicated drive
    - Enterprise-grade NVMe controllers

STORAGE LAYOUT (LOGICAL/PHYSICAL SEPARATION):

  Mount Points:
  /                      - OS root (50 GB)
  /var/lib/postgresql    - DATA directory (2 TB NVMe, RAID 1)
  /var/lib/postgresql/wal - WAL directory (1 TB NVMe, RAID 1)
  /backups               - Backup storage (dedicated partition, HDD acceptable)
  /var/log               - Logs (100 GB SSD, or separate HDD for non-critical logs)

  Benefit of Separation:
  - WAL writes don't contend with data reads
  - I/O patterns are different (WAL is sequential, data is random)
  - Allows independent tuning of each mount point
  - Failure of one drive doesn't block all operations
  - Better performance and reliability

NETWORK:
  - 10 Gbps Ethernet minimum (for high throughput scenarios)
  - Recommendation: Bonded dual 10Gbps NICs (active-active)
  - Dedicated network for replication traffic
  - Firewall rules to restrict database access to application tier only
*/

-- =============================================================
-- Part 3: PostgreSQL INSTALLATION & CONFIGURATION
-- =============================================================

/*
INSTALLATION STEPS (Ubuntu 22.04 LTS):

# 1. Add PostgreSQL repository
sudo apt-get update
sudo apt-get install -y curl gnupg2 lsb-release ubuntu-keyring

curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | \
  sudo tee /usr/share/keyrings/postgresql-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] \
  http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
  sudo tee /etc/apt/sources.list.d/pgdg.list

# 2. Install PostgreSQL 15 (current stable)
sudo apt-get update
sudo apt-get install -y postgresql-15 postgresql-contrib-15 postgresql-client-15

# 3. Enable and start service
sudo systemctl enable postgresql
sudo systemctl start postgresql

# 4. Create data and WAL directories (if separate)
sudo mkdir -p /var/lib/postgresql/15/wal
sudo chown postgres:postgres /var/lib/postgresql/15/wal
sudo chmod 700 /var/lib/postgresql/15/wal

# 5. Initialize cluster with separate WAL
sudo systemctl stop postgresql
sudo -u postgres initdb -D /var/lib/postgresql/15/main \
  -X /var/lib/postgresql/15/wal

# 6. Start service
sudo systemctl start postgresql
*/

-- =============================================================
-- PostgreSQL Configuration: /etc/postgresql/15/main/postgresql.conf
-- =============================================================

/*
RECOMMENDED SETTINGS FOR OUR WORKLOAD (200 concurrent users, 5000 TPS):

# =============================================================
# MEMORY SETTINGS
# =============================================================

shared_buffers = 64GB
# Justification:
# - 25% of 256 GB RAM
# - Minimum recommended: 25%, maximum: 40% of total RAM
# - Allows PostgreSQL to cache frequently accessed pages
# - Reduces need for OS page cache indirection
# - 64 GB = ~250M pages of 8KB each
# - For write-heavy workload, this is conservative but safe
# - Too high: wasted memory (OS cache works well for excess)
# - Too low: excessive disk I/O for repeated page accesses

effective_cache_size = 192GB
# Justification:
# - Typically 50-75% of total RAM
# - 256 GB × 75% = 192 GB
# - Query planner uses this to estimate memory availability
# - Influences join strategy selection (hash join vs nested loop)
# - Higher value encourages index scans over sequential scans

work_mem = 256MB
# Justification:
# - Formula: (total_RAM - shared_buffers) / (max_connections × 2)
# - (256 GB - 64 GB) / (250 × 2) = 192 GB / 500 = ~384 MB
# - Set to 256 MB to be conservative (allow multiple concurrent sorts)
# - Per connection working memory for sorts, hash joins
# - Multiplied by number of concurrent workers, so not too high
# - Too high: memory bloat when many connections sort large datasets
# - Too low: spillover to disk (temporary files slow down queries)

maintenance_work_mem = 2GB
# Justification:
# - Used by VACUUM, ANALYZE, CREATE INDEX, REINDEX
# - Can be set higher than work_mem since these run infrequently
# - 2 GB is reasonable for index maintenance on large tables
# - Faster VACUUM = less bloat, better query performance

# =============================================================
# CONNECTION SETTINGS
# =============================================================

max_connections = 250
# Justification:
# - Expected peak: 200 concurrent users
# - Reserve 25% for superuser/administrative queries: 200 × 1.25 = 250
# - Account for reserved_connections (see below)
# - Each connection: ~10 MB memory overhead (for buffers, query parsing)
# - Too high: waste of memory, slower backend startup
# - Too low: connection rejection errors during peak traffic
# - NOTE: With 250 connections, need connection pooling (see next section)

reserved_connections = 10
# Justification:
# - Reserve 10 slots for superuser operations
# - Ensures DBA can always connect to kill runaway queries
# - Set to: max_connections × 0.04 (4%)
# - If max_connections = 250, reserved = 10

# =============================================================
# CONNECTION POOLING - PgBouncer (CRITICAL FOR 200+ CONCURRENT)
# =============================================================

# PostgreSQL alone cannot handle 200+ concurrent connections efficiently
# because each connection spawns a backend process:
# - Memory overhead: 250 × 10 MB = 2.5 GB just for connection buffers
# - Context switching: CPU spent switching between 250 backends
# - Lock contention: More backends = more lock waiters
# 
# SOLUTION: PgBouncer - lightweight connection pooler
# Benefits:
#   - Reduces actual database backend connections to ~20-50
#   - Multiplexes 200 client connections to 50 backends
#   - Much faster connection reuse (no new process creation)
#   - 1-2 MB per pooled connection (vs 10 MB for direct connection)
#   - Transparent to application (acts like PostgreSQL)
#
# Installation:
# sudo apt-get install -y pgbouncer
#
# Configuration: /etc/pgbouncer/pgbouncer.ini
# [databases]
# ecommerce = host=localhost port=5432 dbname=ecommerce
#
# [pgbouncer]
# listen_port = 6432
# listen_addr = 127.0.0.1
# auth_type = scram-sha-256
# auth_file = /etc/pgbouncer/userlist.txt
# pool_mode = transaction
# max_client_conn = 1000
# default_pool_size = 25          # Backend connections per database
# reserve_pool_size = 5            # Extra backends for burst traffic
# reserve_pool_timeout = 3         # Seconds to wait for backend
# max_db_connections = 50          # Max connections to single DB
# max_user_connections = 100       # Max per user
#
# pool_mode explanation:
# - transaction: Connection returned after each transaction (best for OLTP)
# - session: Connection returned after session ends (stateful connections)
# - statement: Connection returned after each statement (minimal state)
#
# For e-commerce OLTP: pool_mode = transaction is optimal
# 
# Monitoring PgBouncer:
# psql -U pgbouncer -h 127.0.0.1 -p 6432 -d pgbouncer
# SHOW POOLS;
# SHOW STATS;

# =============================================================
# WAL (Write-Ahead Log) SETTINGS
# =============================================================

wal_level = replica
# Justification:
# - Required for streaming replication (high availability)
# - Ensures all changes are logged before applying to data
# - Slight performance overhead vs minimal for durability gain
# - Necessary for PITR (Point-In-Time Recovery)

max_wal_senders = 10
# Justification:
# - Number of concurrent replication connections
# - 1 for each standby replica (max 10 recommended for single primary)
# - Higher = more standbys can connect

wal_keep_size = 16GB
# Justification:
# - Keep at least 16 GB of WAL files locally
# - Ensures standby can catch up if temporarily disconnected
# - WAL file size: 16 MB, so 16 GB = ~1000 WAL files
# - Allows standby 5-10 minutes of lag recovery

checkpoint_completion_target = 0.9
# Justification:
# - Spread checkpoint I/O over 90% of checkpoint interval
# - Reduces I/O spike at checkpoint time
# - Prevents "thundering herd" of dirty page writes

max_wal_size = 32GB
# Justification:
# - Maximum WAL size before forced checkpoint
# - Formula: (RAM × 3) to (RAM × 5)
# - 256 GB × 0.125 = 32 GB
# - Higher = fewer forced checkpoints, larger recovery time
# - Lower = more frequent checkpoints, faster recovery

# =============================================================
# QUERY PLANNING & PERFORMANCE
# =============================================================

random_page_cost = 1.1
# Justification:
# - Cost estimate for random vs sequential page access
# - SSD/NVMe: 1.1 (random access nearly as fast as sequential)
# - HDD: 4.0 (traditional mechanical disk)
# - Tells query planner to prefer index scans on SSDs
# - Default 4.0 is for HDDs; with NVMe this is outdated

effective_io_concurrency = 200
# Justification:
# - How many I/O operations kernel can execute concurrently
# - NVMe SSDs: 50-200 (high capability)
# - For parallel sequential scans
# - Formula: (number_of_spindles × capability_per_spindle)
# - With 2 RAID-1 NVMe drives: 2 × 100 = 200

default_statistics_target = 100
# Justification:
# - Sample size for ANALYZE statistics
# - Default 100; increase to 200-500 for better query planning
# - Especially important for large tables with skewed data
# - Small overhead during ANALYZE, big benefit for query optimization

# =============================================================
# LOGGING & MONITORING
# =============================================================

log_min_duration_statement = 1000
# Justification:
# - Log queries running longer than 1000ms (1 second)
# - Identifies slow queries for optimization
# - Typical: 500ms-2000ms depending on workload
# - Too low: huge log file, I/O overhead
# - Too high: miss slow query patterns

log_connections = on
log_disconnections = on
# Justification:
# - Track login/logout events for security auditing
# - Helps identify connection pool issues, login storms
# - Enable in production for compliance

log_statement = 'mod'
# Justification:
# - Log INSERT, UPDATE, DELETE statements (not SELECT)
# - Reduces log volume while capturing data modifications
# - For full audit, combine with trigger-based audit log (Task 2)

log_lock_waits = on
# Justification:
# - Log when a query waits for a lock >1 second
# - Identifies contention issues, deadlock patterns

# =============================================================
# AUTOVACUUM & MAINTENANCE
# =============================================================

autovacuum = on
autovacuum_naptime = 30s
# Justification:
# - Run autovacuum check every 30 seconds
# - Default 60s; reduce to 30s for high-traffic OLTP
# - Prevents table bloat from frequent updates

autovacuum_vacuum_scale_factor = 0.05
autovacuum_analyze_scale_factor = 0.02
# Justification:
# - Trigger VACUUM when 5% of table has changed
# - Trigger ANALYZE when 2% has changed
# - Default: 0.2 and 0.1 (too infrequent for high-activity tables)
# - For frequently updated tables (orders, customers), lower is better

# =============================================================
# SSL/TLS SECURITY
# =============================================================

ssl = on
ssl_cert_file = '/etc/postgresql/server.crt'
ssl_key_file = '/etc/postgresql/server.key'
ssl_ca_file = '/etc/postgresql/ca.crt'
# Justification:
# - Enable SSL/TLS for all connections
# - Protects credentials and data in transit
# - Self-signed cert acceptable for internal use
# - Production should use CA-signed certificates

# =============================================================
*/

-- =============================================================
-- Part 4: VERIFICATION OF SUCCESSFUL STARTUP
-- =============================================================

/*
VERIFICATION COMMANDS:

1. System Service Status:
$ sudo systemctl status postgresql
Output should show:
  ● postgresql.service - PostgreSQL RDBMS
    Loaded: loaded (/etc/systemd/system/postgresql.service; enabled; vendor preset: enabled)
    Active: active (exited) since <timestamp>
    Process: 1234 ExecStart=... (code=exited, status=0/SUCCESS)

2. Successful Connection via psql:
$ sudo -u postgres psql
psql (15.0 (Debian 15.0-1.pgdg120+1))
Type "help" for help.

postgres=# SELECT version();
                                  version
─────────────────────────────────────────────────────────────
 PostgreSQL 15.0 on x86_64-pc-linux-gnu, compiled by gcc ...
(1 row)

3. Check pg_stat_activity (current connections):
$ psql -U postgres -d postgres -c "SELECT * FROM pg_stat_activity;"

  pid  | usesysid | usename  | application_name | state  | state_change | ... 
────────┬──────────┬──────────┬──────────────────┬────────┬──────────────┼─...
 12345  |       10 | postgres | psql             | idle   | 2026-10-05...  
 12346  |       10 | postgres | pgAdmin 4        | active | 2026-10-05...
(2 rows)

4. Check Database Startup:
$ psql -U postgres -c "SHOW shared_buffers;"
 shared_buffers 
───────────────
 64GB
(1 row)

5. Verify WAL Configuration:
$ psql -U postgres -c "SHOW wal_level; SHOW max_wal_size;"
 wal_level | max_wal_size
───────────┼──────────────
 replica   | 32GB
(1 row)

6. Verify Disk Space & Mount Points:
$ df -h | grep postgresql
/dev/nvme0n1p1  2.0T  123G  1.9T   7% /var/lib/postgresql
/dev/nvme1n1p1  1.0T   45G  980G   5% /var/lib/postgresql/wal

7. Monitor System Performance:
$ iostat -x 5
$ vmstat 2 5
$ top -u postgres

Expected in top:
  postgres processes should consume 64+ GB memory (shared_buffers)
  CPU usage: 5-15% during normal operation, 30-60% during peak load
  I/O wait: <10% (good SSD performance)

8. Test Connection Pooling (PgBouncer):
$ psql -U ecommerce -h 127.0.0.1 -p 6432 -d ecommerce
$ psql -U pgbouncer -h 127.0.0.1 -p 6432 -d pgbouncer
pgbouncer=# SHOW POOLS;
 database | user | cl_active | cl_waiting | sv_active | sv_idle | ...
──────────┼──────┼───────────┼────────────┼───────────┼─────────┼─...
 commerce | app  |        25 |          0 |        10 |      15 | ...
(1 row)

Interpretation:
- cl_active: 25 client connections in transaction
- sv_active: 10 backends actively executing
- sv_idle: 15 backends waiting for next transaction
- This shows pooling is working: 25 clients on 25 backends (inefficient),
  or 100 clients on 25 backends (efficient pooling in transaction mode)
*/

-- =============================================================
-- TROUBLESHOOTING COMMON ISSUES
-- =============================================================

/*
ISSUE: PostgreSQL fails to start

Diagnosis:
$ sudo systemctl status postgresql
$ sudo journalctl -u postgresql -n 50

Common causes:
1. Port already in use
   Solution: Change port in postgresql.conf or kill process on port 5432
   
2. Data directory permissions
   Solution: sudo chown -R postgres:postgres /var/lib/postgresql
   
3. Insufficient memory for shared_buffers
   Solution: Reduce shared_buffers to 25% of available RAM
   
4. Corrupted data directory
   Solution: Backup & reinitialize: 
   sudo -u postgres /usr/lib/postgresql/15/bin/initdb -D /var/lib/postgresql/15/main

ISSUE: Slow queries after startup

Diagnosis:
$ psql -c "SELECT query, mean_time FROM pg_stat_statements 
           ORDER BY mean_time DESC LIMIT 10;"

Common causes:
1. shared_buffers too low → excessive disk I/O
   Solution: Increase shared_buffers (up to 40% RAM)
   
2. Missing indexes
   Solution: Analyze query plans (EXPLAIN ANALYZE)
   
3. Work_mem too low
   Solution: Increase work_mem, restart PostgreSQL

4. Autovacuum not keeping up
   Solution: Increase autovacuum workers or adjust thresholds

ISSUE: Too many connections rejected

Diagnosis:
$ psql -c "SELECT count(*) FROM pg_stat_activity;"

Common causes:
1. max_connections too low
   Solution: Increase max_connections, but use connection pooling
   
2. Connection pool not working
   Solution: Check PgBouncer status:
   $ sudo systemctl status pgbouncer
   $ psql -U pgbouncer -p 6432 -d pgbouncer -c "SHOW POOLS;"

3. Idle connections holding slots
   Solution: Enable idle_in_transaction_session_timeout
   idle_in_transaction_session_timeout = '60s'

ISSUE: High disk I/O, slow performance

Diagnosis:
$ iostat -x 1 10
$ iotop

Common causes:
1. Checkpoint spikes
   Solution: Increase max_wal_size, adjust checkpoint_completion_target
   
2. Sequential scan instead of index
   Solution: Lower random_page_cost (for SSD: 1.1)
   
3. Excessive autovacuum
   Solution: Tune autovacuum_naptime, autovacuum_vacuum_scale_factor
*/

-- =============================================================
-- PRODUCTION DEPLOYMENT CHECKLIST
-- =============================================================

/*
☐ OS Installation
  ☐ Ubuntu 22.04 LTS or RHEL 8/9
  ☐ Firewall configured (restrict access to port 5432)
  ☐ NTP configured (system time synchronized)
  ☐ Swap disabled (PostgreSQL performs poorly with swap)
  
☐ Disk Layout
  ☐ Data directory on NVMe SSD
  ☐ WAL on separate NVMe SSD (or same SSD different partition)
  ☐ Backups on separate storage
  ☐ Filesystem: ext4 or XFS (no btrfs for production)
  
☐ PostgreSQL Installation
  ☐ PostgreSQL 15+ installed
  ☐ pg_stat_statements extension installed (for monitoring)
  ☐ pg_partman installed (for partition management)
  ☐ pgBackRest or pg_dump configured for backups
  
☐ Configuration
  ☐ shared_buffers set correctly (25% RAM)
  ☐ effective_cache_size set (50-75% RAM)
  ☐ work_mem tuned for concurrency
  ☐ max_connections set with headroom
  ☐ random_page_cost = 1.1 (for SSD)
  ☐ SSL/TLS enabled and configured
  ☐ pg_hba.conf configured for access control
  
☐ Connection Pooling
  ☐ PgBouncer installed
  ☐ pool_mode = transaction
  ☐ max_client_conn >= expected peak connections
  ☐ default_pool_size tuned (start with 25-50)
  ☐ Monitoring of pool statistics configured
  
☐ Monitoring & Alerting
  ☐ Prometheus + node_exporter for metrics
  ☐ pg_stat_statements enabled
  ☐ Query logging configured
  ☐ Slow query logging enabled
  ☐ Disk space monitoring (alert at 80% full)
  ☐ Memory utilization monitoring
  ☐ Connection count monitoring
  ☐ Replication lag monitoring (if replicas exist)
  
☐ Backup & Recovery
  ☐ Automated backups scheduled (daily minimum)
  ☐ PITR (Point-In-Time Recovery) configured
  ☐ Backup retention policy defined
  ☐ Recovery tested (restore from backup to verify)
  ☐ WAL archiving configured
  
☐ Security
  ☐ Database user passwords strong (20+ characters)
  ☐ scram-sha-256 password encryption enabled
  ☐ SSH public key authentication for backups
  ☐ Audit logging enabled
  ☐ Least privilege roles configured
  ☐ Network isolation (only app servers connect)
  ☐ SSL/TLS certificates valid and non-expired
  
☐ Testing
  ☐ Connection pooling tested (200+ concurrent connections)
  ☐ Failover tested (if using HA setup)
  ☐ Backup/restore tested (full cycle)
  ☐ Performance baseline established
  ☐ Load testing performed (at expected peak)
*/

-- =============================================================
-- Example: CREATE MONITORING DATABASE AFTER INSTALL
-- =============================================================

-- Install pg_stat_statements extension
-- sudo -u postgres psql -d postgres -c "CREATE EXTENSION pg_stat_statements;"

-- Create monitoring user
-- CREATE ROLE monitor WITH LOGIN PASSWORD 'monitor_password_123';
-- GRANT CONNECT ON DATABASE postgres TO monitor;
-- GRANT pg_monitor TO monitor;  -- Built-in role for monitoring

-- Example query to find slow statements
-- SELECT query, calls, mean_time, max_time 
-- FROM pg_stat_statements 
-- WHERE mean_time > 1000  -- Queries slower than 1 second
-- ORDER BY mean_time DESC;

-- =============================================================
-- End of file
-- =============================================================
