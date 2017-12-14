function motifsegment = testsegmentation(path,batch,motif,dtwtemplate,dtwtemplate2,minint,mindur,thresh,CHANSPEC,fs);
%this function extracts the onset/offset of syllables within target motif
%based on different segmentation methods 
%dtwtemplate = spectral exemplar template from make_dtw_temp
%dtwtemplate2 = amplitude env exemplar template make_dtw2_temp_motif
%fs = sampling rate
%CHANSPEC = 'obs0' for cbin files from evtaf of 'w' for wav files 
%minint: min gap length for amp segmentation (ms)
%mindur: min syll length
%thresh: 0-1, amp threshold for segmenting normalized amp waveform
%six differeng segmentation methods:
%amplitude: based on fixed threshold on smoothed amp waveform,
%min-max normalized
%dtw: based on spectral features, compare to exemplar motif
%peak: based on halfwidth locations of detected peaks, think of as adaptive
%amplitude threshold
%dtwpeak: mix of dtw spectral features and peak segmentation
%tonality: based on when spectrum becomes more tonal (less like white
%noise)
%dtwamp: dtw on the amplitude envelope

nbuffer = floor(0.016*fs);%buffer by 16 ms

%params for spectrogram
NFFT = 512;
overlap = NFFT-10;
t=-NFFT/2+1:NFFT/2;
sigma=(1/1000)*fs;
w=exp(-(t/sigma).^2);

%frequency range for tonality measure
[pxx freq] = pwelch(dtwtemplate.filtsong,NFFT,overlap,NFFT,fs);
pxx = pxx./sum(pxx);
prc = cumsum(pxx);
id = find(prc>=0.25 & prc<=0.75);
freq = [freq(id(1)) freq(id(end))];

ff = load_batchf([path batch]);
motif_cnt = 0;
motifsegment = struct();
for i = 1:length(ff)
    %load song data
    fn = [path ff(i).name];
    fnn=[fn,'.not.mat'];
    if (~exist(fnn,'file'))
        continue;
    end
    load(fnn);
    rd = readrecf(fn);
    
    [pthstr,tnm,ext] = fileparts(fn);
    if (strcmp(CHANSPEC,'w'))
            [dat,fs] = audioread(fn);
    elseif (strcmp(ext,'.ebin'))
        [dat,fs]=readevtaf(fn,CHANSPEC);
    else
        [dat,fs]=evsoundin('',fn,CHANSPEC);
    end
    if (isempty(dat))
        disp(['hey no data!']);
        continue;
    end
    
    %find motifs in bout
    p = strfind(labels,motif);
    if isempty(p)
        continue
    end

    %get smoothed amp waveform of motif 
    for ii = 1:length(p)
        ton = onsets(p(ii));
        toff=offsets(p(ii)+length(motif)-1);
        onsamp = ceil((ton*1e-3)*fs);
        offsamp = ceil((toff*1e-3)*fs);
        if offsamp+nbuffer > length(dat)
            offsamp = length(dat);
        else
            offsamp = offsamp+nbuffer;
        end
        if onsamp-nbuffer < 1
            onsamp = 1;
        else
            onsamp = onsamp-nbuffer;
        end
        smtemp = dat(onsamp:offsamp);%amplitude envelope of motif
        filtsong = bandpass(smtemp,fs,500,10000,'hanningffir');
        sm = evsmooth(smtemp,fs,'','','',5);%smoothed amplitude envelop
        
        %amplitude segmentation
        sm2 = log(sm);sm2=sm2-min(sm2);sm2=sm2/max(sm2);
        [ampons ampoffs] = SegmentNotes(sm2,fs,minint,mindur,thresh);
        
        %dtw segmentation on spectrogram
        [dtwons dtwoffs] = dtw_segment(smtemp,dtwtemplate,fs);
        
        %peak segmentation
        [pkons pkoffs] = peaksegment(smtemp,fs);
        
        %peak + dtw segmentation
        [dtwpkons dtwpkoffs] = peaksegment(smtemp,fs,dtwtemplate);
        
        %tonality segmentation
%         [tonons tonoffs] = tonalitysegment(smtemp,fs,freq);
        
        %dtw segmentation on amplitude envelope
        [dtwons2 dtwoffs2] = dtw2_segment(sm2,dtwtemplate2,fs);
       
       %extract datenum from rec file, add syllable ton in seconds
       if (strcmp(CHANSPEC,'obs0'))
             if isfield(rd,'header')
                key = 'created:';
                ind = strfind(rd.header{1},key);
                tmstamp = rd.header{1}(ind+length(key):end);
                try
                    tmstamp = datenum(tmstamp,'ddd, mmm dd, yyyy, HH:MM:SS');%time file was closed
                    ind2 = strfind(rd.header{5},'=');
                    filelength = sscanf(rd.header{5}(ind2 + 1:end),'%g');%duration of file

                    tm_st = addtodate(tmstamp,-(filelength),'millisecond');%time at start of filefiltsong
                    datenm = addtodate(tm_st, round(ton), 'millisecond');%add time to onset of syllable
                    [yr mon dy hr minutes sec] = datevec(datenm);     
                catch
                    datenm = fn2datenum(fn);
                end
             else 
                 datenm = fn2datenum(fn);
             end
      elseif strcmp(CHANSPEC,'w')
            datenm = wavefn2datenum(fn);
      end
     
     motif_cnt = motif_cnt+1;
     motifsegment(motif_cnt).smtemp = smtemp;
     motifsegment(motif_cnt).filename = fn;
     motifsegment(motif_cnt).datenm = datenm;
     motifsegment(motif_cnt).sm = sm;
     motifsegment(motif_cnt).ampsegment = [ampons ampoffs];
     motifsegment(motif_cnt).dtwsegment = [dtwons dtwoffs];
     motifsegment(motif_cnt).pksegment = [pkons pkoffs];
     motifsegment(motif_cnt).dtwpksegment = [dtwpkons dtwpkoffs];
%      motifsegment(motif_cnt).tonalitysegment = [tonons tonoffs];
     motifsegment(motif_cnt).dtwampsegment = [dtwons2 dtwoffs2];

    end
    
    if motif_cnt >= 50 %only sample 50 motifs because of time
         return
    end
end
        
        
        