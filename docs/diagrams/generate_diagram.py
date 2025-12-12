#!/usr/bin/env python3
"""
Azure Communication Services - Enterprise Architecture Diagram

This script generates architecture diagrams for the ACS reference architecture
using the diagrams library (https://diagrams.mingrammer.com/).

Requirements:
    pip install diagrams

Usage:
    python generate_diagram.py

Output:
    - acs_architecture.png (main architecture)
    - acs_landing_zone.png (landing zone view)
    - acs_data_flow.png (data flow diagram)
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.azure.compute import AppServices, FunctionApps, ContainerApps
from diagrams.azure.database import CosmosDb, BlobStorage
from diagrams.azure.integration import EventGridDomains, APIManagement
from diagrams.azure.security import KeyVaults
from diagrams.azure.identity import ManagedIdentities, ActiveDirectory
from diagrams.azure.network import VirtualNetworks, Subnets, NetworkSecurityGroupsClassic
from diagrams.azure.monitor import Monitor, ApplicationInsights
from diagrams.azure.general import Resourcegroups
from diagrams.onprem.client import Users, Client
from diagrams.generic.device import Mobile, Tablet
from diagrams.programming.framework import React

# Diagram attributes for consistent styling
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "spline",
}

node_attr = {
    "fontsize": "12",
}

edge_attr = {
    "fontsize": "10",
}


def create_main_architecture():
    """Generate the main architecture diagram."""
    
    with Diagram(
        "Azure Communication Services - Enterprise Architecture",
        filename="acs_architecture",
        show=False,
        direction="TB",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr,
    ):
        # Client Applications
        with Cluster("Client Applications"):
            web_app = React("Web App\n(React)")
            mobile_app = Mobile("Mobile App\n(iOS/Android)")
            bot = Client("Bot/Automation")
        
        # Azure Landing Zone
        with Cluster("Azure Landing Zone - Application Subscription"):
            
            # API Layer
            with Cluster("API Layer"):
                apim = APIManagement("API Management\n(Rate limiting, Auth)")
            
            # Application Tier
            with Cluster("Application Tier"):
                app_service = AppServices("App Service\n(Backend API)")
                functions = FunctionApps("Azure Functions\n(Event Processing)")
                container_app = ContainerApps("Container Apps\n(Microservices)")
            
            # Communication Services
            with Cluster("Azure Communication Services"):
                acs = Resourcegroups("ACS Resource")
                event_grid = EventGridDomains("Event Grid\n(Webhooks)")
            
            # Security & Identity
            with Cluster("Security & Identity"):
                key_vault = KeyVaults("Key Vault\n(Secrets)")
                managed_id = ManagedIdentities("Managed Identity")
                entra_id = ActiveDirectory("Entra ID")
            
            # Data Layer
            with Cluster("Data Layer"):
                cosmos_db = CosmosDb("Cosmos DB\n(Chat History)")
                blob_storage = BlobStorage("Blob Storage\n(Recordings)")
            
            # Monitoring
            with Cluster("Monitoring"):
                log_analytics = Monitor("Log Analytics")
                app_insights = ApplicationInsights("App Insights")
        
        # Client to API connections
        web_app >> Edge(label="HTTPS") >> apim
        mobile_app >> Edge(label="HTTPS") >> apim
        bot >> Edge(label="HTTPS") >> apim
        
        # API to Application tier
        apim >> app_service
        apim >> functions
        apim >> container_app
        
        # Application to ACS
        app_service >> Edge(label="Voice/Video/Chat") >> acs
        functions >> Edge(label="SMS/Email") >> acs
        container_app >> Edge(label="Advanced Messaging") >> acs
        
        # ACS Events
        acs >> Edge(label="Events") >> event_grid
        event_grid >> Edge(label="Trigger") >> functions
        
        # Security connections
        app_service >> Edge(style="dashed") >> key_vault
        functions >> Edge(style="dashed") >> key_vault
        app_service >> Edge(style="dashed") >> managed_id
        managed_id >> Edge(style="dashed") >> entra_id
        
        # Data connections
        functions >> Edge(label="Store") >> cosmos_db
        acs >> Edge(label="Recordings") >> blob_storage
        
        # Monitoring connections
        acs >> Edge(style="dotted", color="gray") >> log_analytics
        app_service >> Edge(style="dotted", color="gray") >> app_insights
        functions >> Edge(style="dotted", color="gray") >> app_insights


def create_landing_zone_diagram():
    """Generate the Azure Landing Zone integration diagram."""
    
    with Diagram(
        "Azure Communication Services - Landing Zone Integration",
        filename="acs_landing_zone",
        show=False,
        direction="TB",
        graph_attr=graph_attr,
    ):
        users = Users("End Users")
        
        with Cluster("Azure Landing Zone"):
            
            # Connectivity Subscription
            with Cluster("Connectivity Subscription"):
                hub_vnet = VirtualNetworks("Hub VNet")
                nsg_hub = NetworkSecurityGroupsClassic("Hub NSG")
            
            # Identity Subscription
            with Cluster("Identity Subscription"):
                entra = ActiveDirectory("Entra ID")
            
            # Management Subscription
            with Cluster("Management Subscription"):
                monitor = Monitor("Azure Monitor")
                log_analytics = ApplicationInsights("Log Analytics\nWorkspace")
            
            # Landing Zone - Application
            with Cluster("Landing Zone - ACS Application"):
                with Cluster("Spoke VNet"):
                    spoke_vnet = VirtualNetworks("Spoke VNet")
                    
                    with Cluster("Application Subnet"):
                        app_snet = Subnets("App Subnet")
                        app_svc = AppServices("App Service")
                    
                    with Cluster("Integration Subnet"):
                        int_snet = Subnets("Integration Subnet")
                        functions = FunctionApps("Functions")
                    
                    with Cluster("Data Subnet"):
                        data_snet = Subnets("Data Subnet")
                        cosmos = CosmosDb("Cosmos DB")
                
                # ACS (Region-agnostic)
                acs = Resourcegroups("Azure\nCommunication\nServices")
                kv = KeyVaults("Key Vault")
        
        # Connections
        users >> hub_vnet
        hub_vnet >> spoke_vnet
        
        app_svc >> acs
        functions >> acs
        
        app_svc >> kv
        functions >> kv
        
        app_svc >> cosmos
        functions >> cosmos
        
        acs >> Edge(style="dotted") >> log_analytics
        app_svc >> Edge(style="dotted") >> monitor


def create_data_flow_diagram():
    """Generate the data flow diagram."""
    
    with Diagram(
        "Azure Communication Services - Data Flow",
        filename="acs_data_flow",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        with Cluster("1. User Initiates"):
            user = Users("User")
            web = React("Web/Mobile App")
        
        with Cluster("2. Authentication"):
            entra = ActiveDirectory("Entra ID")
            token = KeyVaults("ACS Token")
        
        with Cluster("3. Communication"):
            acs = Resourcegroups("ACS")
            with Cluster("Capabilities"):
                voice = Client("Voice")
                video = Mobile("Video")
                chat = Tablet("Chat")
        
        with Cluster("4. Processing"):
            events = EventGridDomains("Event Grid")
            functions = FunctionApps("Functions")
        
        with Cluster("5. Storage"):
            cosmos = CosmosDb("Chat History")
            blob = BlobStorage("Recordings")
        
        with Cluster("6. Monitoring"):
            insights = ApplicationInsights("App Insights")
        
        # Flow
        user >> Edge(label="1. Access") >> web
        web >> Edge(label="2. Auth") >> entra
        entra >> Edge(label="3. Token") >> token
        token >> Edge(label="4. Connect") >> acs
        
        acs >> voice
        acs >> video
        acs >> chat
        
        acs >> Edge(label="5. Events") >> events
        events >> Edge(label="6. Process") >> functions
        functions >> Edge(label="7. Store") >> cosmos
        acs >> Edge(label="8. Record") >> blob
        
        acs >> Edge(style="dotted", label="9. Telemetry") >> insights


if __name__ == "__main__":
    print("Generating Azure Communication Services architecture diagrams...")
    
    print("  → Creating main architecture diagram...")
    create_main_architecture()
    
    print("  → Creating landing zone diagram...")
    create_landing_zone_diagram()
    
    print("  → Creating data flow diagram...")
    create_data_flow_diagram()
    
    print("\n✅ Diagrams generated successfully!")
    print("   - acs_architecture.png")
    print("   - acs_landing_zone.png")
    print("   - acs_data_flow.png")
