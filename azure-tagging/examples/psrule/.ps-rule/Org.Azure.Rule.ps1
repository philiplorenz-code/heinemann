# Synopsis: Resource groups must have nonblank mandatory tags and an allowed environment.
Rule 'Org.Azure.RG.Tags' -Type 'Microsoft.Resources/resourceGroups' {
    $hasTags = $Assert.HasField($TargetObject, 'tags')
    if (!$hasTags.Result) {
        return $hasTags
    }
    foreach ($key in @('Application', 'OwnerTeam', 'CostCenter')) {
        $Assert.HasField($TargetObject.tags, $key, $True)
        $Assert.Match($TargetObject, "tags.$key", '\S', $True)
    }
    $Assert.In($TargetObject, 'tags.Environment', @('dev', 'test', 'prod'), $True)
}
