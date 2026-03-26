import json
import csv

def print_data(data):
    # Print raw JSON (formatted)
    print(json.dumps(data, indent=2))

    # Write complianceDetails into CSV
    with open('./output/posture_data.csv', 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = [
            'id',
            'name',
            'description',
            'assigned_policies',
            'failed_resources',
            'passed_resources',
            'total_resources',
            'critical_severity_failed_resources',
            'high_severity_failed_resources',
            'medium_severity_failed_resources',
            'low_severity_failed_resources',
            'informational_severity_failed_resources',
            'is_default',
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for item in data.get('complianceDetails', []):
            writer.writerow({
                'id': item.get('id'),
                'name': item.get('name'),
                'description': item.get('description'),
                'assigned_policies': item.get('assignedPolicies'),
                'failed_resources': item.get('failedResources'),
                'passed_resources': item.get('passedResources'),
                'total_resources': item.get('totalResources'),
                'critical_severity_failed_resources': item.get('criticalSeverityFailedResources'),
                'high_severity_failed_resources': item.get('highSeverityFailedResources'),
                'medium_severity_failed_resources': item.get('mediumSeverityFailedResources'),
                'low_severity_failed_resources': item.get('lowSeverityFailedResources'),
                'informational_severity_failed_resources': item.get('informationalSeverityFailedResources'),
                'is_default': item.get('default'),
            })