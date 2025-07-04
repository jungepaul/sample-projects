#!/usr/bin/env python3
"""
Feast Feature Definitions for AI/ML Platform

This module contains feature definitions, entities, and feature views
for the machine learning platform.
"""

from feast import Entity, Feature, FeatureView, FileSource, ValueType
from feast.data_source import RequestSource
from feast.feature_transformation import SubtractTimestampTransform
from datetime import timedelta
import pandas as pd


# =============================================================================
# ENTITIES
# =============================================================================

# User/Customer Entity
user_entity = Entity(
    name="user_id",
    value_type=ValueType.INT64,
    description="Unique identifier for users/customers",
    tags={"team": "customer_analytics", "domain": "user"}
)

# Driver Entity (for ride-sharing example)
driver_entity = Entity(
    name="driver_id", 
    value_type=ValueType.INT64,
    description="Unique identifier for drivers",
    tags={"team": "driver_analytics", "domain": "driver"}
)

# Product Entity
product_entity = Entity(
    name="product_id",
    value_type=ValueType.STRING,
    description="Unique identifier for products",
    tags={"team": "product_analytics", "domain": "product"}
)

# Location Entity
location_entity = Entity(
    name="location_id",
    value_type=ValueType.INT64,
    description="Unique identifier for geographical locations",
    tags={"team": "geo_analytics", "domain": "location"}
)


# =============================================================================
# DATA SOURCES
# =============================================================================

# User activity data source
user_activity_source = FileSource(
    name="user_activity_source",
    path="s3://ai-ml-platform-ml-dev-datasets/feast/user_activity/",
    timestamp_field="event_timestamp",
    created_timestamp_column="created_timestamp",
    description="User activity and engagement metrics",
    tags={"source": "user_events", "format": "parquet"}
)

# Driver performance data source
driver_performance_source = FileSource(
    name="driver_performance_source", 
    path="s3://ai-ml-platform-ml-dev-datasets/feast/driver_performance/",
    timestamp_field="event_timestamp",
    created_timestamp_column="created_timestamp",
    description="Driver performance and behavior metrics",
    tags={"source": "driver_events", "format": "parquet"}
)

# Product catalog data source
product_catalog_source = FileSource(
    name="product_catalog_source",
    path="s3://ai-ml-platform-ml-dev-datasets/feast/product_catalog/",
    timestamp_field="event_timestamp", 
    created_timestamp_column="created_timestamp",
    description="Product information and metadata",
    tags={"source": "product_catalog", "format": "parquet"}
)

# Transaction data source
transaction_source = FileSource(
    name="transaction_source",
    path="s3://ai-ml-platform-ml-dev-datasets/feast/transactions/",
    timestamp_field="event_timestamp",
    created_timestamp_column="created_timestamp", 
    description="Financial transaction data",
    tags={"source": "transactions", "format": "parquet"}
)

# Real-time user activity source (for streaming features)
user_activity_stream_source = RequestSource(
    name="user_activity_stream_source",
    schema=[
        Feature(name="current_session_duration", dtype=ValueType.INT64),
        Feature(name="pages_viewed_session", dtype=ValueType.INT64),
        Feature(name="current_device_type", dtype=ValueType.STRING),
    ],
    description="Real-time user activity for current session"
)


# =============================================================================
# FEATURE VIEWS
# =============================================================================

# User Engagement Features
user_engagement_features = FeatureView(
    name="user_engagement_features",
    entities=["user_id"],
    ttl=timedelta(days=7),
    features=[
        Feature(name="total_sessions_7d", dtype=ValueType.INT64, 
                description="Total sessions in last 7 days"),
        Feature(name="avg_session_duration_7d", dtype=ValueType.FLOAT,
                description="Average session duration in last 7 days (minutes)"),
        Feature(name="total_page_views_7d", dtype=ValueType.INT64,
                description="Total page views in last 7 days"),
        Feature(name="unique_pages_viewed_7d", dtype=ValueType.INT64,
                description="Unique pages viewed in last 7 days"),
        Feature(name="bounce_rate_7d", dtype=ValueType.FLOAT,
                description="Bounce rate in last 7 days"),
        Feature(name="conversion_rate_7d", dtype=ValueType.FLOAT,
                description="Conversion rate in last 7 days"),
        Feature(name="last_activity_hours_ago", dtype=ValueType.FLOAT,
                description="Hours since last activity"),
    ],
    online=True,
    batch_source=user_activity_source,
    tags={"team": "growth", "category": "engagement"}
)

# User Demographics Features  
user_demographics_features = FeatureView(
    name="user_demographics_features",
    entities=["user_id"],
    ttl=timedelta(days=30),
    features=[
        Feature(name="age_group", dtype=ValueType.STRING,
                description="User age group (18-25, 26-35, etc.)"),
        Feature(name="country", dtype=ValueType.STRING,
                description="User country"),
        Feature(name="city", dtype=ValueType.STRING,
                description="User city"),
        Feature(name="signup_days_ago", dtype=ValueType.INT64,
                description="Days since user signup"),
        Feature(name="is_premium_user", dtype=ValueType.BOOL,
                description="Whether user has premium subscription"),
        Feature(name="preferred_language", dtype=ValueType.STRING,
                description="User's preferred language"),
    ],
    online=True,
    batch_source=user_activity_source,
    tags={"team": "customer_success", "category": "demographics"}
)

# Driver Performance Features
driver_performance_features = FeatureView(
    name="driver_performance_features", 
    entities=["driver_id"],
    ttl=timedelta(days=1),
    features=[
        Feature(name="avg_rating_30d", dtype=ValueType.FLOAT,
                description="Average driver rating in last 30 days"),
        Feature(name="total_trips_30d", dtype=ValueType.INT64,
                description="Total trips completed in last 30 days"),
        Feature(name="total_earnings_30d", dtype=ValueType.FLOAT,
                description="Total earnings in last 30 days"),
        Feature(name="acceptance_rate_30d", dtype=ValueType.FLOAT,
                description="Trip acceptance rate in last 30 days"),
        Feature(name="cancellation_rate_30d", dtype=ValueType.FLOAT,
                description="Trip cancellation rate in last 30 days"),
        Feature(name="avg_trip_duration_30d", dtype=ValueType.FLOAT,
                description="Average trip duration in last 30 days (minutes)"),
        Feature(name="peak_hours_activity_30d", dtype=ValueType.FLOAT,
                description="Percentage of activity during peak hours"),
    ],
    online=True,
    batch_source=driver_performance_source,
    tags={"team": "driver_ops", "category": "performance"}
)

# Product Features
product_features = FeatureView(
    name="product_features",
    entities=["product_id"],
    ttl=timedelta(days=1),
    features=[
        Feature(name="category", dtype=ValueType.STRING,
                description="Product category"),
        Feature(name="price", dtype=ValueType.FLOAT,
                description="Current product price"),
        Feature(name="discount_percentage", dtype=ValueType.FLOAT,
                description="Current discount percentage"),
        Feature(name="avg_rating", dtype=ValueType.FLOAT,
                description="Average product rating"),
        Feature(name="total_reviews", dtype=ValueType.INT64,
                description="Total number of reviews"),
        Feature(name="inventory_count", dtype=ValueType.INT64,
                description="Current inventory count"),
        Feature(name="is_trending", dtype=ValueType.BOOL,
                description="Whether product is currently trending"),
        Feature(name="days_since_launch", dtype=ValueType.INT64,
                description="Days since product launch"),
    ],
    online=True,
    batch_source=product_catalog_source,
    tags={"team": "product", "category": "catalog"}
)

# Transaction Features
transaction_features = FeatureView(
    name="transaction_features",
    entities=["user_id"],
    ttl=timedelta(days=7),
    features=[
        Feature(name="total_spent_7d", dtype=ValueType.FLOAT,
                description="Total amount spent in last 7 days"),
        Feature(name="total_spent_30d", dtype=ValueType.FLOAT,
                description="Total amount spent in last 30 days"),
        Feature(name="transaction_count_7d", dtype=ValueType.INT64,
                description="Number of transactions in last 7 days"),
        Feature(name="transaction_count_30d", dtype=ValueType.INT64,
                description="Number of transactions in last 30 days"),
        Feature(name="avg_transaction_amount_30d", dtype=ValueType.FLOAT,
                description="Average transaction amount in last 30 days"),
        Feature(name="max_transaction_amount_30d", dtype=ValueType.FLOAT,
                description="Maximum transaction amount in last 30 days"),
        Feature(name="unique_merchants_30d", dtype=ValueType.INT64,
                description="Number of unique merchants in last 30 days"),
        Feature(name="failed_transactions_7d", dtype=ValueType.INT64,
                description="Number of failed transactions in last 7 days"),
    ],
    online=True,
    batch_source=transaction_source,
    tags={"team": "payments", "category": "transactions"}
)

# Real-time User Session Features
user_session_features = FeatureView(
    name="user_session_features",
    entities=["user_id"],
    ttl=timedelta(hours=1),
    features=[
        Feature(name="current_session_duration", dtype=ValueType.INT64,
                description="Current session duration in minutes"),
        Feature(name="pages_viewed_session", dtype=ValueType.INT64,
                description="Pages viewed in current session"),
        Feature(name="current_device_type", dtype=ValueType.STRING,
                description="Device type for current session"),
    ],
    online=True,
    batch_source=user_activity_stream_source,
    tags={"team": "real_time", "category": "session"}
)


# =============================================================================
# FEATURE SERVICES (for model serving)
# =============================================================================

from feast import FeatureService

# Recommendation Model Feature Service
recommendation_feature_service = FeatureService(
    name="recommendation_v1",
    features=[
        user_engagement_features[["total_sessions_7d", "avg_session_duration_7d", "conversion_rate_7d"]],
        user_demographics_features[["age_group", "country", "is_premium_user"]],
        transaction_features[["total_spent_30d", "avg_transaction_amount_30d"]],
        product_features[["category", "price", "avg_rating", "is_trending"]],
    ],
    tags={"model": "recommendation", "version": "v1"}
)

# Fraud Detection Feature Service
fraud_detection_feature_service = FeatureService(
    name="fraud_detection_v1", 
    features=[
        transaction_features[["transaction_count_7d", "avg_transaction_amount_30d", "failed_transactions_7d"]],
        user_demographics_features[["country", "signup_days_ago"]],
        user_session_features[["current_device_type"]],
    ],
    tags={"model": "fraud_detection", "version": "v1"}
)

# Driver Matching Feature Service
driver_matching_feature_service = FeatureService(
    name="driver_matching_v1",
    features=[
        driver_performance_features[["avg_rating_30d", "acceptance_rate_30d", "total_trips_30d"]],
    ],
    tags={"model": "driver_matching", "version": "v1"}
)

# Customer Churn Prediction Feature Service
churn_prediction_feature_service = FeatureService(
    name="churn_prediction_v1",
    features=[
        user_engagement_features[["total_sessions_7d", "last_activity_hours_ago", "bounce_rate_7d"]],
        user_demographics_features[["signup_days_ago", "is_premium_user"]],
        transaction_features[["transaction_count_30d", "total_spent_30d"]],
    ],
    tags={"model": "churn_prediction", "version": "v1"}
)


# =============================================================================
# FEATURE STORE REGISTRY
# =============================================================================

# List of all entities
ENTITIES = [
    user_entity,
    driver_entity,
    product_entity,
    location_entity,
]

# List of all feature views
FEATURE_VIEWS = [
    user_engagement_features,
    user_demographics_features,
    driver_performance_features,
    product_features,
    transaction_features,
    user_session_features,
]

# List of all feature services
FEATURE_SERVICES = [
    recommendation_feature_service,
    fraud_detection_feature_service,
    driver_matching_feature_service,
    churn_prediction_feature_service,
]

# List of all data sources
DATA_SOURCES = [
    user_activity_source,
    driver_performance_source,
    product_catalog_source,
    transaction_source,
    user_activity_stream_source,
]


def apply_feature_definitions(store):
    """
    Apply all feature definitions to the given Feast store
    
    Args:
        store: Feast FeatureStore instance
    """
    print("Applying entities...")
    store.apply(ENTITIES)
    
    print("Applying feature views...")
    store.apply(FEATURE_VIEWS)
    
    print("Applying feature services...")
    store.apply(FEATURE_SERVICES)
    
    print("Feature definitions applied successfully!")


if __name__ == "__main__":
    from feast import FeatureStore
    
    # Initialize feature store
    store = FeatureStore(repo_path=".")
    
    # Apply all feature definitions
    apply_feature_definitions(store)
    
    print("\nFeature Store Summary:")
    print(f"Entities: {len(ENTITIES)}")
    print(f"Feature Views: {len(FEATURE_VIEWS)}")
    print(f"Feature Services: {len(FEATURE_SERVICES)}")
    print(f"Data Sources: {len(DATA_SOURCES)}")