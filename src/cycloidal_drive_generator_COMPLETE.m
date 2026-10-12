%% cycloidal_drive_master.m
% Parametric single-stage cycloidal drive generator.
%
% Change targetRatio to 10, 15, 20, etc.
% The script creates:
%   1) cycloidal_disc_<ratio>to1.dxf
%   2) ring_pin_pattern_<ratio>to1.dxf
%   3) cycloidal_disc_<ratio>to1.txt
%   4) output_hole_centers_<ratio>to1.csv
%   5) ring_pin_centers_<ratio>to1.csv
%   6) design_summary_<ratio>to1.txt
%
% IMPORTANT:
% This generates nominal 2D geometry. Final bearing fits, printed clearances,
% shaft details, housing dimensions, fillets, tolerances, and strength checks
% still need to be completed in SolidWorks.

clear; clc; close all;

%% ================================================================
%  1. USER SETTINGS -- CHANGE THESE FIRST
%  ================================================================

targetRatio = 20;       % Try 10, 15, 20, etc.

% Main cycloidal geometry
R  = 40.0;             % Fixed ring-pin pitch radius [mm]
Rr = 3.0;              % Fixed ring-pin radius [mm] (6 mm diameter)

% Eccentricity
eccentricityFactor = 0.50;
% E = eccentricityFactor*(R/N)
% 0.50 is a conservative starting point.
% Do not increase this without looking at the resulting profile.

% Curve resolution
numPoints = 1440;      % More points = smoother CAD curve, larger file

% Disc-center bearing/bore
centerBoreDiameter = 22.0;  % 22 mm OD for a bearing 608

% Output carrier / output-pin system
numOutputPins      = 6;
outputPinDiameter  = 6.0;   % Output roller/pin diameter [mm]
outputPitchRadius  = 20.0;  % Radius from disc center to output-hole centers [mm]
outputClearance    = 0.20;  % Radial running clearance [mm]

% Ring housing reference geometry
housingWall = 6.0;           % Reference material beyond ring pins [mm]

%% ================================================================
%  2. AUTOMATIC RATIO GEOMETRY
%  ================================================================

% For this single-stage layout:
% number of fixed pins N = number of disc lobes + 1
% reduction ratio = N - 1

N = targetRatio + 1;
numLobes = N - 1;

E = eccentricityFactor * (R / N);

% Output holes must allow the disc to orbit by eccentricity E.
% Nominal hole diameter:
% output roller diameter + 2*eccentricity + running-clearance allowance
outputHoleDiameter = outputPinDiameter + 2*E + 2*outputClearance;

% Basic geometric sanity checks
if targetRatio < 3 || floor(targetRatio) ~= targetRatio
    error('targetRatio must be an integer >= 3.');
end

if R <= 0 || Rr <= 0 || E <= 0
    error('R, Rr, and E must all be positive.');
end

if E >= R/N
    warning('E is at or above R/N. The disc may develop sharp or invalid geometry.');
end

if outputPitchRadius + outputHoleDiameter/2 >= R - Rr
    warning(['Output-hole pattern is getting close to the cycloidal perimeter. ' ...
             'Inspect the SolidWorks sketch carefully and increase R or reduce the output pattern if needed.']);
end

%% ================================================================
%  3. GENERATE CYCLOIDAL DISC PROFILE
%  ================================================================

[X, Y] = cycloidal_profile(R, Rr, E, N, numPoints);

%% ================================================================
%  4. GENERATE OUTPUT-HOLE CENTERS
%  ================================================================

aOut = (0:numOutputPins-1).' * (2*pi/numOutputPins);
outputHoleX = outputPitchRadius*cos(aOut);
outputHoleY = outputPitchRadius*sin(aOut);
outputCenters = [outputHoleX, outputHoleY];

%% ================================================================
%  5. GENERATE FIXED RING-PIN CENTERS
%  ================================================================

aRing = (0:N-1).' * (2*pi/N);
ringPinX = R*cos(aRing);
ringPinY = R*sin(aRing);
ringCenters = [ringPinX, ringPinY];

housingOuterRadius = R + Rr + housingWall;

%% ================================================================
%  6. Ex OUTPUT FOLDER / FILENAMES
%  ================================================================

folderName = sprintf('cycloidal_%dto1_output', targetRatio);
if ~exist(folderName, 'dir')
    mkdir(folderName);
end

discDXF    = fullfile(folderName, sprintf('cycloidal_disc_%dto1.dxf', targetRatio));
ringDXF    = fullfile(folderName, sprintf('ring_pin_pattern_%dto1.dxf', targetRatio));
xyzFile    = fullfile(folderName, sprintf('cycloidal_disc_%dto1.txt', targetRatio));
outCSV     = fullfile(folderName, sprintf('output_hole_centers_%dto1.csv', targetRatio));
ringCSV    = fullfile(folderName, sprintf('ring_pin_centers_%dto1.csv', targetRatio));
summaryFile= fullfile(folderName, sprintf('design_summary_%dto1.txt', targetRatio));

%% ================================================================
%  7. Ex DISC DXF
%  ================================================================

write_disc_dxf(discDXF, X, Y, centerBoreDiameter, outputCenters, outputHoleDiameter);

%% ================================================================
%  8. Ex RING-PIN PATTERN DXF
%  ================================================================

write_ring_dxf(ringDXF, ringCenters, Rr, housingOuterRadius);

%% ================================================================
%  9. Ex XYZ PROFILE
%  ================================================================

Z = zeros(size(X));

% Write XYZ as plain text. Using fopen/fprintf avoids MATLAB's
% writematrix extension check for the nonstandard .xyz extension.
fidXYZ = fopen(xyzFile, 'w');
if fidXYZ < 0
    error('Could not open %s for writing.', xyzFile);
end
fprintf(fidXYZ, '%.8f %.8f %.8f\n', [X(:), Y(:), Z(:)].');
fclose(fidXYZ);

%% ================================================================
% 10. Ex COORDINATE TABLES
%  ================================================================

Toutput = table((1:numOutputPins).', outputHoleX, outputHoleY, ...
    'VariableNames', {'PinNumber','X_mm','Y_mm'});
writetable(Toutput, outCSV);

Tring = table((1:N).', ringPinX, ringPinY, ...
    'VariableNames', {'PinNumber','X_mm','Y_mm'});
writetable(Tring, ringCSV);

%% ================================================================
% 11. DESIGN SUMMARY
%  ================================================================

fid = fopen(summaryFile, 'w');

fprintf(fid, 'PARAMETRIC CYCLOIDAL DRIVE DESIGN SUMMARY\n');
fprintf(fid, '=========================================\n\n');

fprintf(fid, 'Target reduction ratio     : %d:1\n', targetRatio);
fprintf(fid, 'Fixed ring pins, N         : %d\n', N);
fprintf(fid, 'Cycloidal disc lobes       : %d\n', numLobes);
fprintf(fid, 'Ring-pin pitch radius, R   : %.4f mm\n', R);
fprintf(fid, 'Ring-pin radius, Rr        : %.4f mm\n', Rr);
fprintf(fid, 'Ring-pin diameter          : %.4f mm\n', 2*Rr);
fprintf(fid, 'Eccentricity, E            : %.4f mm\n', E);
fprintf(fid, 'Eccentricity factor        : %.4f\n', eccentricityFactor);
fprintf(fid, 'Center bore diameter       : %.4f mm\n', centerBoreDiameter);
fprintf(fid, 'Number of output pins      : %d\n', numOutputPins);
fprintf(fid, 'Output-pin diameter        : %.4f mm\n', outputPinDiameter);
fprintf(fid, 'Output pitch radius        : %.4f mm\n', outputPitchRadius);
fprintf(fid, 'Output-hole diameter       : %.4f mm\n', outputHoleDiameter);
fprintf(fid, 'Output running clearance   : %.4f mm radial\n', outputClearance);
fprintf(fid, 'Reference housing OD       : %.4f mm\n', 2*housingOuterRadius);
fprintf(fid, 'Profile points             : %d\n', numPoints);

fprintf(fid, '\nNOTES\n');
fprintf(fid, '-----\n');
fprintf(fid, '1. Ratio = N - 1 for this single-stage geometry.\n');
fprintf(fid, '2. The DXF files contain nominal 2D sketches in millimeters.\n');
fprintf(fid, '3. Final manufacturing clearances and fits must be chosen for your process.\n');
fprintf(fid, '4. Check interference and motion in the SolidWorks assembly before manufacturing.\n');
fprintf(fid, '5. The ring DXF shows pin circles and a reference housing outer circle.\n');

fclose(fid);

%% ================================================================
% 12. PLOT FOR VISUAL CHECK
%  ================================================================

figure;
hold on;
axis equal;
grid on;

plot([X X(1)], [Y Y(1)], 'LineWidth', 1.5);

th = linspace(0, 2*pi, 180);

% Center bore
plot((centerBoreDiameter/2)*cos(th), ...
     (centerBoreDiameter/2)*sin(th), 'LineWidth', 1.0);

% Output holes
for i = 1:numOutputPins
    plot(outputHoleX(i) + (outputHoleDiameter/2)*cos(th), ...
         outputHoleY(i) + (outputHoleDiameter/2)*sin(th), ...
         'LineWidth', 1.0);
end

% Ring pins
for i = 1:N
    plot(ringPinX(i) + Rr*cos(th), ...
         ringPinY(i) + Rr*sin(th), '--');
end

title(sprintf('%d:1 Cycloidal Drive | %d Pins | %d Lobes | E = %.3f mm', ...
      targetRatio, N, numLobes, E));

xlabel('X [mm]');
ylabel('Y [mm]');

fprintf('\n====================================================\n');
fprintf('CYCLOIDAL DRIVE GENERATED\n');
fprintf('====================================================\n');
fprintf('Ratio              : %d:1\n', targetRatio);
fprintf('Fixed ring pins    : %d\n', N);
fprintf('Disc lobes         : %d\n', numLobes);
fprintf('Eccentricity       : %.4f mm\n', E);
fprintf('Output-hole dia.   : %.4f mm\n', outputHoleDiameter);
fprintf('Output folder      : %s\n', folderName);
fprintf('====================================================\n\n');

%% ================================================================
% LOCAL FUNCTION: CYCLOIDAL PROFILE
% Uses the same profile relationship as the original generator.
% ================================================================

function [X, Y] = cycloidal_profile(R, Rr, E, N, numPoints)

    t = linspace(0, 2*pi, numPoints + 1);
    t(end) = [];  % DXF is explicitly closed later; avoid duplicate endpoint.

    psi = atan2( sin((1 - N).*t), ...
                (R/(E*N)) - cos((1 - N).*t) );

    X = R.*cos(t) - Rr.*cos(t + psi) - E.*cos(N.*t);
    Y = -R.*sin(t) + Rr.*sin(t + psi) + E.*sin(N.*t);
end

%% ================================================================
% LOCAL FUNCTION: WRITE DISC DXF
% Creates:
%   - closed cycloidal perimeter
%   - center bearing/bore circle
%   - output-hole circles
% ================================================================

function write_disc_dxf(filename, X, Y, centerBoreDiameter, ...
                        outputCenters, outputHoleDiameter)

    fid = fopen(filename, 'w');
    if fid < 0
        error('Could not open %s for writing.', filename);
    end

    dxf_begin(fid);

    % Cycloidal perimeter
    dxf_profile_as_lines(fid, X(:), Y(:));

    % Center bore
    dxf_circle(fid, 0, 0, centerBoreDiameter/2);

    % Output holes
    for i = 1:size(outputCenters,1)
        dxf_circle(fid, outputCenters(i,1), outputCenters(i,2), ...
                   outputHoleDiameter/2);
    end

    dxf_end(fid);
    fclose(fid);
end

%% ================================================================
% LOCAL FUNCTION: WRITE RING-PIN DXF
% Creates:
%   - fixed pin circles
%   - reference housing outer circle
% ================================================================

function write_ring_dxf(filename, ringCenters, ringPinRadius, housingOuterRadius)

    fid = fopen(filename, 'w');
    if fid < 0
        error('Could not open %s for writing.', filename);
    end

    dxf_begin(fid);

    % Pin circles / pin-hole locations
    for i = 1:size(ringCenters,1)
        dxf_circle(fid, ringCenters(i,1), ringCenters(i,2), ringPinRadius);
    end

    % Reference outside diameter of housing
    dxf_circle(fid, 0, 0, housingOuterRadius);

    dxf_end(fid);
    fclose(fid);
end

%% ================================================================
% DXF HELPERS
% ================================================================

function dxf_begin(fid)
    % Very simple AutoCAD R12-style DXF.
    % LINE and CIRCLE entities are broadly compatible with SolidWorks.
    fprintf(fid, '0\nSECTION\n');
    fprintf(fid, '2\nHEADER\n');
    fprintf(fid, '9\n$ACADVER\n');
    fprintf(fid, '1\nAC1009\n');
    fprintf(fid, '0\nENDSEC\n');

    fprintf(fid, '0\nSECTION\n');
    fprintf(fid, '2\nENTITIES\n');
end

function dxf_end(fid)
    fprintf(fid, '0\nENDSEC\n');
    fprintf(fid, '0\nEOF\n');
end

function dxf_profile_as_lines(fid, X, Y)
    % Write the cycloidal perimeter as individual LINE entities.
    % This is less elegant than a polyline, but much more universally
    % accepted by CAD importers.

    n = numel(X);

    for i = 1:n-1
        dxf_line(fid, X(i), Y(i), X(i+1), Y(i+1));
    end

    % Close the final segment
    dxf_line(fid, X(n), Y(n), X(1), Y(1));
end

function dxf_line(fid, x1, y1, x2, y2)
    fprintf(fid, '0\nLINE\n');
    fprintf(fid, '8\n0\n');

    fprintf(fid, '10\n%.8f\n', x1);
    fprintf(fid, '20\n%.8f\n', y1);
    fprintf(fid, '30\n0.0\n');

    fprintf(fid, '11\n%.8f\n', x2);
    fprintf(fid, '21\n%.8f\n', y2);
    fprintf(fid, '31\n0.0\n');
end

function dxf_circle(fid, Xc, Yc, radius)
    fprintf(fid, '0\nCIRCLE\n');
    fprintf(fid, '8\n0\n');

    fprintf(fid, '10\n%.8f\n', Xc);
    fprintf(fid, '20\n%.8f\n', Yc);
    fprintf(fid, '30\n0.0\n');

    fprintf(fid, '40\n%.8f\n', radius);
end
