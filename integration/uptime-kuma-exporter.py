#!/usr/bin/env python3
"""
Uptime Kuma Prometheus Exporter
================================

Bridges Uptime Kuma API to Prometheus metrics format.
Converts uptime monitoring data to Prometheus-compatible metrics.

Usage:
    python uptime-kuma-exporter.py --uptime-kuma-url=http://uptime-kuma:3001 --listen=0.0.0.0:5000

Features:
    - Scrapes Uptime Kuma API
    - Converts monitor data to Prometheus metrics
    - Exposes /metrics endpoint
    - Handles errors gracefully
    - Supports multiple monitor types

Metrics Exposed:
    - uptime_monitor_up (1=up, 0=down)
    - uptime_monitor_response_time_ms (milliseconds)
    - uptime_monitor_uptime_percent (0-100)
    - uptime_monitor_status_page_enabled
"""

import os
import sys
import time
import logging
import argparse
from typing import Dict, List, Any

try:
    import requests
    from prometheus_client import (
        Counter,
        Gauge,
        Histogram,
        start_http_server,
        CollectorRegistry,
        generate_latest,
        REGISTRY,
    )
except ImportError:
    print("Error: Required packages not found. Install with:")
    print("  pip install requests prometheus-client")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# ============================================================================
# Prometheus Metrics
# ============================================================================

# Monitor status (1 = UP, 0 = DOWN)
metric_monitor_up = Gauge(
    'uptime_monitor_up',
    'Monitor current status (1=up, 0=down)',
    ['monitor_name', 'monitor_id', 'monitor_type']
)

# Monitor response time in milliseconds
metric_response_time = Gauge(
    'uptime_monitor_response_time_ms',
    'Monitor response time in milliseconds',
    ['monitor_name', 'monitor_id']
)

# Monitor uptime percentage (0-100)
metric_uptime_percent = Gauge(
    'uptime_monitor_uptime_percent',
    'Monitor uptime percentage over 24 hours',
    ['monitor_name', 'monitor_id']
)

# Monitor downtime count
metric_downtime_count = Counter(
    'uptime_monitor_downtime_events_total',
    'Total number of downtime events',
    ['monitor_name', 'monitor_id']
)

# Last check timestamp
metric_last_check = Gauge(
    'uptime_monitor_last_check_timestamp_seconds',
    'Timestamp of last monitor check',
    ['monitor_name', 'monitor_id']
)

# Scrape duration
metric_scrape_duration = Histogram(
    'uptime_exporter_scrape_duration_seconds',
    'Time taken to scrape Uptime Kuma API',
    buckets=[0.1, 0.5, 1, 2, 5, 10]
)

# Scrape errors
metric_scrape_errors = Counter(
    'uptime_exporter_scrape_errors_total',
    'Total number of scrape errors'
)

# ============================================================================
# Uptime Kuma API Client
# ============================================================================

class UptimeKumaClient:
    """Client for Uptime Kuma API"""
    
    def __init__(self, base_url: str, timeout: int = 10):
        """
        Initialize the Uptime Kuma API client
        
        Args:
            base_url: Base URL of Uptime Kuma (e.g., http://uptime-kuma:3001)
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.session = requests.Session()
        
    def get_monitors(self) -> List[Dict[str, Any]]:
        """
        Fetch all monitors from Uptime Kuma
        
        Returns:
            List of monitor dictionaries
            
        Raises:
            requests.RequestException: If API request fails
        """
        try:
            url = f"{self.base_url}/api/monitors"
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
            
            # Handle different response formats
            if isinstance(data, dict) and 'data' in data:
                return data['data']
            elif isinstance(data, list):
                return data
            else:
                logger.warning(f"Unexpected API response format: {type(data)}")
                return []
                
        except requests.RequestException as e:
            logger.error(f"Failed to fetch monitors from {url}: {e}")
            raise
    
    def get_monitor_status(self, monitor_id: int) -> Dict[str, Any]:
        """
        Fetch status of a specific monitor
        
        Args:
            monitor_id: ID of the monitor
            
        Returns:
            Monitor status dictionary
        """
        try:
            url = f"{self.base_url}/api/monitors/{monitor_id}/status"
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.warning(f"Failed to fetch monitor {monitor_id} status: {e}")
            return {}
    
    def get_status_page(self) -> Dict[str, Any]:
        """Fetch status page information"""
        try:
            url = f"{self.base_url}/api/status-page/info"
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            logger.debug(f"Failed to fetch status page info: {e}")
            return {}

# ============================================================================
# Prometheus Exporter
# ============================================================================

class UptimeKumaExporter:
    """Exports Uptime Kuma data as Prometheus metrics"""
    
    def __init__(self, uptime_kuma_url: str):
        """
        Initialize the exporter
        
        Args:
            uptime_kuma_url: Base URL of Uptime Kuma instance
        """
        self.client = UptimeKumaClient(uptime_kuma_url)
        
    def update_metrics(self):
        """
        Fetch data from Uptime Kuma and update Prometheus metrics
        """
        start_time = time.time()
        
        try:
            # Fetch all monitors
            monitors = self.client.get_monitors()
            logger.info(f"Fetched {len(monitors)} monitors")
            
            # Update metrics for each monitor
            for monitor in monitors:
                self._update_monitor_metrics(monitor)
            
            duration = time.time() - start_time
            metric_scrape_duration.observe(duration)
            logger.info(f"Metrics updated in {duration:.2f}s")
            
        except Exception as e:
            logger.error(f"Error updating metrics: {e}")
            metric_scrape_errors.inc()
    
    def _update_monitor_metrics(self, monitor: Dict[str, Any]):
        """
        Update Prometheus metrics for a single monitor
        
        Args:
            monitor: Monitor data from Uptime Kuma API
        """
        try:
            monitor_id = str(monitor.get('id', 'unknown'))
            monitor_name = monitor.get('name', 'unknown').replace(' ', '_').lower()
            monitor_type = monitor.get('type', 'unknown')
            
            # Status: 1 = UP, 0 = DOWN
            # Status value: 1 = UP, 0 = DOWN, 2 = PAUSED, etc.
            status = monitor.get('status', 0)
            status_value = 1 if status == 1 else 0
            
            metric_monitor_up.labels(
                monitor_name=monitor_name,
                monitor_id=monitor_id,
                monitor_type=monitor_type
            ).set(status_value)
            
            # Response time
            response_time = monitor.get('average_response_time', 0)
            if response_time:
                metric_response_time.labels(
                    monitor_name=monitor_name,
                    monitor_id=monitor_id
                ).set(float(response_time))
            
            # Uptime percentage (if available)
            uptime = monitor.get('uptime', 0)
            if uptime:
                metric_uptime_percent.labels(
                    monitor_name=monitor_name,
                    monitor_id=monitor_id
                ).set(float(uptime) * 100)
            
            # Last check time
            last_check = monitor.get('lastCheck', 0)
            if last_check:
                metric_last_check.labels(
                    monitor_name=monitor_name,
                    monitor_id=monitor_id
                ).set(float(last_check) / 1000)  # Convert ms to seconds
            
            logger.debug(
                f"Updated metrics for monitor {monitor_name} "
                f"(id={monitor_id}, status={status_value})"
            )
            
        except Exception as e:
            logger.warning(f"Error processing monitor data: {e}")

# ============================================================================
# Flask HTTP Server
# ============================================================================

def create_app(exporter: UptimeKumaExporter):
    """Create Flask application for metrics endpoint"""
    try:
        from flask import Flask
    except ImportError:
        logger.error("Flask not found. Install with: pip install flask")
        sys.exit(1)
    
    app = Flask(__name__)
    
    @app.route('/metrics')
    def metrics():
        """Prometheus metrics endpoint"""
        exporter.update_metrics()
        return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain'}
    
    @app.route('/health')
    def health():
        """Health check endpoint"""
        return {'status': 'ok'}, 200
    
    @app.route('/')
    def index():
        """Index page with basic info"""
        return {
            'name': 'Uptime Kuma Prometheus Exporter',
            'version': '1.0.0',
            'metrics': '/metrics',
            'health': '/health'
        }, 200
    
    return app

# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Uptime Kuma Prometheus Exporter'
    )
    parser.add_argument(
        '--uptime-kuma-url',
        default=os.getenv('UPTIME_KUMA_URL', 'http://uptime-kuma:3001'),
        help='Base URL of Uptime Kuma instance'
    )
    parser.add_argument(
        '--listen',
        default=os.getenv('LISTEN', '0.0.0.0:5000'),
        help='Address and port to listen on (format: host:port)'
    )
    parser.add_argument(
        '--log-level',
        default=os.getenv('LOG_LEVEL', 'INFO'),
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Logging level'
    )
    
    args = parser.parse_args()
    
    # Set logging level
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    # Parse listen address
    host, port = args.listen.split(':')
    port = int(port)
    
    logger.info(f"Starting Uptime Kuma Prometheus Exporter")
    logger.info(f"  Uptime Kuma URL: {args.uptime_kuma_url}")
    logger.info(f"  Listen: {host}:{port}")
    
    try:
        # Create exporter
        exporter = UptimeKumaExporter(args.uptime_kuma_url)
        
        # Create Flask app
        app = create_app(exporter)
        
        # Start HTTP server
        logger.info(f"Starting HTTP server on {host}:{port}")
        app.run(host=host, port=port, threaded=True, debug=False)
        
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
