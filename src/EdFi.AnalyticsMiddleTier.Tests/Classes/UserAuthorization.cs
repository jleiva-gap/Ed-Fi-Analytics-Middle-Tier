﻿// SPDX-License-Identifier: Apache-2.0
// Licensed to the Ed-Fi Alliance under one or more agreements.
// The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
// See the LICENSE and NOTICES files in the project root for more information.

using System.Diagnostics.CodeAnalysis;

namespace EdFi.AnalyticsMiddleTier.Tests.Classes
{
    [SuppressMessage("ReSharper", "UnusedMember.Global")]
    public class UserAuthorization
    {
        public int UserKey { get; set; } //(int, not null)
        public string UserScope { get; set; } //(varchar(50), null)
        public string StudentPermission { get; set; } //(varchar(3), not null)
        public string SectionPermission { get; set; } //(varchar(50), null)
        public string SectionKeyPermission { get; set; }
        public string SchoolPermission { get; set; } //(varchar(30), null)
        public int? DistrictId { get; set; } //(int, null)
    }
}