// This file contains your Data Connector logic
[Version = "1.0.0"]
section AdvantechCounting;

api_uri = "https://dev-api-apps.wise-apps.com";
pos_uri = "https://dev-pos.wise-apps.com";
access_key = "Eb1mUtnAIS9si8TZ";
form_header = [#"Content-Type" = "application/x-www-form-urlencoded"];
json_header = [#"Content-Type" = "application/json"];

[DataSource.Kind="AdvantechCounting", Publish="AdvantechCounting.Publish"]
shared AdvantechCounting.Navigation = () as table => 
    let
        objects = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Functions", "Functions", FunctionTable(), "Folder", "Functions", false }
            }
        ),
        navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;



FunctionTable = () as table => 
    let
        objects = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "GetSite", "GetSite", AdvantechCounting.GetSite, "Function", "GetSite", true }
            }
        ),
        navTable = Table.ForceToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable; 


AdvantechCounting.GetSite = Value.ReplaceType(GetSite, GetSiteType);
    GetSiteType = type function (
        acc_id as ( type text meta [
            Documentation.FieldCaption = "Acc ID",
            Documentation.FieldDescription = "Acc ID",
            Documentation.SampleValues = {"Acc ID"}
        ])
    ) as table meta [
        Documentation.Name = "GetSite"
    ];

    GetSite = (acc_id as text) => 
    let
        PostContent = Json.FromValue([ acc_id = acc_id ]),
        res = Json.Document(Web.Contents(api_uri & "/api/store/namelist", [ Headers = form_header, Content = PostContent])),
        site = res[stores] ?? {},
        show = Table.SelectColumns(Table.FromRecords(site), { "store_id", "store_name", "country", "province", "city" })
    in
        show;

AdvantechCounting.GetData = Value.ReplaceType(GetSite, GetSiteType);
    GetDataType = type function (
        store_id as ( type text meta [
            Documentation.FieldCaption = "Site ID",
            Documentation.FieldDescription = "Site ID",
            Documentation.SampleValues = {"Site ID"}
        ]),
        start_date as (type date meta [
            Documentation.FieldCaption = "Start Date",
            Documentation.FieldDescription = "Start Date"
        ]),
        end_date as (type date meta [
            Documentation.FieldCaption = "End Date",
            Documentation.FieldDescription = "End Date"
        ]),
        data_unit as ( type text meta [
            Documentation.FieldCaption = "Data Unit",
            Documentation.FieldDescription = "Data Unit",
            Documentation.AllowedValues = {"Day", "Hour"}
        ])
    ) as table meta [
        Documentation.Name = "GetData"
    ];

    GetData = (store_id as text, start_date as date, end_date as date, data_unit as text) => 
    let
        PostContent = Json.FromValue([ store_id = store_id, access_key = access_key ]),
        res = Json.Document(Web.Contents(api_uri & "/api/store/info", [ Headers = form_header, Content = PostContent])),
        site = res[store] ?? [],
        
        show = Table.SelectColumns(Table.FromRecords(site), { "store_id", "store_name", "country", "province", "city" })
    in
        show;

// Data Source Kind description
AdvantechCounting = [
    TestConnection = (dataSourcePath) => {"AdvantechCounting.Navigation"},
    Authentication = [
        // Key = [],
        // UsernamePassword = [
        //     UsernameLabel = Extension.LoadString("Username"),
        //     PasswordLabel = Extension.LoadString("Password"),
        //     Label = Extension.LoadString("AuthenticationLabel")
        // ],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
AdvantechCounting.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = AdvantechCounting.Icons,
    SourceTypeImage = AdvantechCounting.Icons
];

AdvantechCounting.Icons = [
    Icon16 = { Extension.Contents("AdvantechCounting16.png"), Extension.Contents("AdvantechCounting20.png"), Extension.Contents("AdvantechCounting24.png"), Extension.Contents("AdvantechCounting32.png") },
    Icon32 = { Extension.Contents("AdvantechCounting32.png"), Extension.Contents("AdvantechCounting40.png"), Extension.Contents("AdvantechCounting48.png"), Extension.Contents("AdvantechCounting64.png") }
];

// Common library code
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

Table.ForceToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
