import { useState } from "react";

const C = {
  orange:   "#FF9500",
  orangeL:  "#FFAC33",
  orangeD:  "#FF7A00",
  orangeBg: "rgba(255,149,0,0.10)",
  orangeBg2:"rgba(255,149,0,0.06)",
  white:    "#FFFFFF",
  bg:       "#F6F6F9",
  ink:      "#16121D",
  ink55:    "rgba(22,18,29,0.55)",
  ink30:    "rgba(22,18,29,0.30)",
  ink12:    "rgba(22,18,29,0.12)",
  ink06:    "rgba(22,18,29,0.06)",
};
const grad = "linear-gradient(135deg,#FFAC33,#FF7A00)";
const shadow = {
  card: "0 4px 18px rgba(22,18,29,0.07),0 1px 3px rgba(22,18,29,0.05)",
  btn:  "0 6px 22px rgba(255,149,0,0.36),0 2px 6px rgba(255,149,0,0.18)",
};

const GradText = ({children,size=13,weight=700})=>(
  <span style={{background:grad,WebkitBackgroundClip:"text",WebkitTextFillColor:"transparent",fontSize:size,fontWeight:weight,fontFamily:"'DM Sans',sans-serif"}}>{children}</span>
);

const TEMPLATES = [
  { id:"A", label:"スタンダード", bg:"#FFFFFF", textColor:C.ink },
  { id:"B", label:"オレンジ",    bg:"linear-gradient(135deg,#FFAC33,#FF7A00)", textColor:"#FFFFFF" },
  { id:"C", label:"ダーク",      bg:"#16121D", textColor:"#FFFFFF" },
];

const APP = {
  icon:"⏱", name:"Focus Timer Pro",
  dev:"Taro Yamada", rating:4.3, category:"仕事効率化",
  desc:"シンプルで使いやすいポモドーロタイマー。",
};

function OgpCard({ template, message, unlocked }) {
  const isGrad = template.bg.includes("gradient");
  const isDark = template.bg === "#16121D";

  return (
    <div style={{
      width:"100%", aspectRatio:"1.91/1",
      background: template.bg,
      borderRadius:16,
      padding:"20px 22px",
      display:"flex", flexDirection:"column", justifyContent:"space-between",
      position:"relative", overflow:"hidden",
      boxShadow: shadow.card,
      border: (!isGrad && !isDark) ? `1px solid ${C.ink06}` : "none",
    }}>
      {/* subtle pattern overlay for white */}
      {!isGrad && !isDark && (
        <div style={{
          position:"absolute", inset:0, borderRadius:16,
          background:"radial-gradient(ellipse at 90% 10%, rgba(255,172,51,0.08) 0%, transparent 60%)",
          pointerEvents:"none",
        }}/>
      )}

      {/* top: app info */}
      <div style={{display:"flex",alignItems:"center",gap:12}}>
        <div style={{
          width:48,height:48,borderRadius:12,flexShrink:0,
          background: isGrad||isDark ? "rgba(255,255,255,0.15)" : C.orangeBg,
          display:"flex",alignItems:"center",justifyContent:"center",
          fontSize:26,
        }}>{APP.icon}</div>
        <div>
          <div style={{
            fontFamily:"'Zen Maru Gothic',sans-serif",
            fontWeight:700,fontSize:15,
            color: template.textColor,
          }}>{APP.name}</div>
          <div style={{fontSize:11,color: isGrad||isDark ? "rgba(255,255,255,0.7)" : C.ink55,marginTop:2}}>
            {APP.dev} · {APP.category}
          </div>
          <div style={{display:"flex",alignItems:"center",gap:4,marginTop:3}}>
            <span style={{color: isGrad ? "#fff" : isDark ? "#FFAC33" : C.orange,fontSize:11}}>★★★★☆</span>
            <span style={{fontSize:11,color: isGrad||isDark ? "rgba(255,255,255,0.7)" : C.ink55}}>{APP.rating}</span>
          </div>
        </div>
      </div>

      {/* message */}
      <div style={{
        fontFamily:"'Zen Maru Gothic',sans-serif",
        fontWeight:700,
        fontSize:14,
        color: template.textColor,
        lineHeight:1.6,
        opacity: unlocked ? 1 : 0.3,
        filter: unlocked ? "none" : "blur(3px)",
        transition:"all 0.3s",
      }}>
        {message || "ここにカスタム文言が入ります"}
      </div>

      {/* bottom: badge */}
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between"}}>
        <div style={{
          fontSize:10,fontWeight:700,
          color: isGrad||isDark ? "rgba(255,255,255,0.6)" : C.ink30,
          fontFamily:"'DM Sans',sans-serif",letterSpacing:1,textTransform:"uppercase",
        }}>App Store</div>
        <div style={{
          padding:"4px 12px",borderRadius:999,
          background: isGrad ? "rgba(255,255,255,0.25)" : isDark ? "rgba(255,149,0,0.25)" : grad,
          fontSize:11,fontWeight:700,
          color: isGrad ? "#fff" : isDark ? "#FFAC33" : "#fff",
          fontFamily:"'DM Sans',sans-serif",
        }}>ダウンロード</div>
      </div>

      {/* lock overlay */}
      {!unlocked && (
        <div style={{
          position:"absolute",inset:0,borderRadius:16,
          display:"flex",alignItems:"center",justifyContent:"center",
          background:"rgba(246,246,249,0.5)",backdropFilter:"blur(1px)",
        }}>
          <div style={{
            background:C.white,borderRadius:14,padding:"8px 16px",
            boxShadow:shadow.card,
            fontSize:12,fontWeight:700,color:C.ink55,
            fontFamily:"'DM Sans',sans-serif",
          }}>🔒 動画を見てカスタマイズ</div>
        </div>
      )}
    </div>
  );
}

export default function App() {
  const [step, setStep]           = useState(0); // 0=locked 1=watch 2=unlocked
  const [template, setTemplate]   = useState(TEMPLATES[0]);
  const [message, setMessage]     = useState("レビューお願いします！\nぜひ使ってみてください🙏");
  const [watching, setWatching]   = useState(false);
  const [progress, setProgress]   = useState(0);

  const unlocked = step === 2;

  const handleWatch = () => {
    setWatching(true);
    setProgress(0);
    let p = 0;
    const iv = setInterval(()=>{
      p += 2;
      setProgress(p);
      if(p >= 100){
        clearInterval(iv);
        setWatching(false);
        setStep(2);
      }
    }, 60);
  };

  return (
    <div style={{
      fontFamily:"'DM Sans',sans-serif",
      background:C.bg, minHeight:"100vh", color:C.ink,
      maxWidth:390, margin:"0 auto",
    }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Zen+Maru+Gothic:wght@700;900&family=DM+Sans:wght@400;500;700&display=swap');`}</style>

      {/* Header */}
      <div style={{background:C.white,padding:"52px 24px 16px",boxShadow:`0 1px 0 ${C.ink06}`}}>
        <div style={{marginBottom:4}}><GradText size={13}>みんなのレビュー</GradText></div>
        <div style={{fontFamily:"'Zen Maru Gothic',sans-serif",fontSize:20,fontWeight:900,letterSpacing:-0.5}}>
          シェアカードを作る
        </div>
      </div>

      <div style={{padding:"16px 16px 80px",display:"flex",flexDirection:"column",gap:14}}>

        {/* App info */}
        <div style={{
          background:C.white,borderRadius:18,padding:"12px 14px",
          boxShadow:shadow.card,display:"flex",alignItems:"center",gap:12,
        }}>
          <div style={{
            width:44,height:44,borderRadius:11,flexShrink:0,
            background:C.orangeBg,display:"flex",alignItems:"center",justifyContent:"center",fontSize:24,
          }}>{APP.icon}</div>
          <div>
            <div style={{fontFamily:"'Zen Maru Gothic',sans-serif",fontWeight:700,fontSize:14}}>{APP.name}</div>
            <div style={{fontSize:12,color:C.ink55}}>{APP.dev}</div>
          </div>
          <div style={{marginLeft:"auto",fontSize:11,color:C.ink30,fontWeight:700}}>変更</div>
        </div>

        {/* OGP Preview */}
        <div>
          <div style={{fontSize:10,fontWeight:700,letterSpacing:1.8,color:C.ink30,textTransform:"uppercase",marginBottom:10,fontFamily:"'DM Sans',sans-serif"}}>
            プレビュー
          </div>
          <OgpCard template={template} message={message} unlocked={unlocked}/>
        </div>

        {/* Template selector */}
        <div style={{background:C.white,borderRadius:18,padding:16,boxShadow:shadow.card}}>
          <div style={{fontSize:10,fontWeight:700,letterSpacing:1.8,color:C.ink30,textTransform:"uppercase",marginBottom:12,fontFamily:"'DM Sans',sans-serif"}}>
            テンプレート
          </div>
          <div style={{display:"flex",gap:10}}>
            {TEMPLATES.map(t=>{
              const sel = template.id===t.id;
              return (
                <button key={t.id} onClick={()=>unlocked&&setTemplate(t)} style={{
                  flex:1,padding:"10px 4px",borderRadius:12,
                  background:t.bg,
                  border: sel ? `2px solid ${C.orange}` : `1.5px solid ${C.ink06}`,
                  cursor: unlocked?"pointer":"not-allowed",
                  position:"relative",overflow:"hidden",
                  opacity: unlocked?1:0.5,
                }}>
                  <div style={{fontSize:10,fontWeight:700,color:t.textColor==="#FFFFFF"?"#fff":C.ink55,fontFamily:"'DM Sans',sans-serif"}}>{t.label}</div>
                  {sel && <div style={{position:"absolute",top:4,right:4,width:8,height:8,borderRadius:"50%",background:C.orange}}/>}
                  {!unlocked && <div style={{position:"absolute",inset:0,display:"flex",alignItems:"center",justifyContent:"center",fontSize:14}}>🔒</div>}
                </button>
              );
            })}
          </div>
        </div>

        {/* Message editor */}
        <div style={{background:C.white,borderRadius:18,padding:16,boxShadow:shadow.card}}>
          <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,letterSpacing:1.8,color:C.ink30,textTransform:"uppercase",fontFamily:"'DM Sans',sans-serif"}}>
              文言
            </div>
            {!unlocked && (
              <div style={{fontSize:11,color:C.orange,fontWeight:700}}>🔒 要アンロック</div>
            )}
          </div>

          {unlocked ? (
            <textarea
              value={message}
              onChange={e=>setMessage(e.target.value)}
              rows={3}
              maxLength={80}
              style={{
                width:"100%",borderRadius:12,padding:"10px 12px",
                border:`1.5px solid ${C.ink12}`,
                background:C.bg,color:C.ink,fontSize:13,
                fontFamily:"'Zen Maru Gothic',sans-serif",
                lineHeight:1.6,resize:"none",outline:"none",
                boxSizing:"border-box",
              }}
            />
          ) : (
            <div style={{
              borderRadius:12,padding:"10px 12px",
              background:C.bg,color:C.ink30,fontSize:13,
              fontFamily:"'Zen Maru Gothic',sans-serif",lineHeight:1.6,
              filter:"blur(3px)",userSelect:"none",
            }}>
              レビューお願いします！<br/>ぜひ使ってみてください🙏
            </div>
          )}

          {unlocked && (
            <div style={{fontSize:11,color:C.ink30,textAlign:"right",marginTop:6}}>
              {message.length}/80
            </div>
          )}

          {/* suggested phrases */}
          {unlocked && (
            <div style={{marginTop:10}}>
              <div style={{fontSize:10,color:C.ink30,marginBottom:6}}>候補文言</div>
              <div style={{display:"flex",flexWrap:"wrap",gap:6}}>
                {["レビューお願いします！","使ってみてね✨","新作リリースしました！","ぜひ試してみて🙏"].map(s=>(
                  <button key={s} onClick={()=>setMessage(s)} style={{
                    padding:"4px 10px",borderRadius:999,
                    background:C.orangeBg2,border:`1px solid rgba(255,149,0,0.2)`,
                    fontSize:11,color:C.orange,fontWeight:600,cursor:"pointer",
                    fontFamily:"'DM Sans',sans-serif",
                  }}>{s}</button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Unlock / Watch ad / Share */}
        {step === 0 && (
          <div style={{background:C.orangeBg2,borderRadius:18,padding:16,boxShadow:shadow.card}}>
            <div style={{fontFamily:"'Zen Maru Gothic',sans-serif",fontSize:13,fontWeight:700,marginBottom:6}}>
              <GradText size={13}>✦ カスタマイズをアンロック</GradText>
            </div>
            <div style={{fontSize:12,color:C.ink55,lineHeight:1.7,marginBottom:14}}>
              動画を1本見ると、文言・テンプレートを自由に変更できます。アンロックは当日中有効です。
            </div>
            <button onClick={handleWatch} style={{
              width:"100%",padding:"13px 0",borderRadius:999,
              background:grad,border:"none",cursor:"pointer",
              color:"#fff",fontSize:14,fontWeight:700,
              fontFamily:"'DM Sans',sans-serif",boxShadow:shadow.btn,
            }}>動画を見てアンロック</button>
          </div>
        )}

        {step === 1 && watching && (
          <div style={{background:C.white,borderRadius:18,padding:16,boxShadow:shadow.card}}>
            <div style={{fontSize:12,color:C.ink55,marginBottom:10,textAlign:"center"}}>広告視聴中...</div>
            <div style={{height:8,background:C.ink06,borderRadius:4,overflow:"hidden",marginBottom:6}}>
              <div style={{height:"100%",width:`${progress}%`,background:grad,borderRadius:4,transition:"width 0.1s"}}/>
            </div>
            <div style={{fontSize:11,color:C.ink30,textAlign:"center"}}>{Math.ceil((100-progress)/2*0.06)}秒後にスキップ可能</div>
          </div>
        )}

        {step === 2 && (
          <>
            <div style={{
              background:"rgba(34,197,94,0.06)",borderRadius:18,padding:"12px 16px",
              border:"1px solid rgba(34,197,94,0.2)",
              fontSize:12,color:"#16A34A",fontWeight:600,textAlign:"center",
            }}>
              ✓ カスタマイズがアンロックされました（本日中有効）
            </div>

            <button style={{
              width:"100%",padding:"14px 0",borderRadius:999,
              background:grad,border:"none",cursor:"pointer",
              color:"#fff",fontSize:15,fontWeight:700,
              fontFamily:"'DM Sans',sans-serif",boxShadow:shadow.btn,
            }}>
              シェアする
            </button>
          </>
        )}

        {step === 0 && (
          <button style={{
            width:"100%",padding:"13px 0",borderRadius:999,
            background:C.white,border:`1.5px solid ${C.ink12}`,cursor:"pointer",
            color:C.ink55,fontSize:14,fontWeight:700,
            fontFamily:"'DM Sans',sans-serif",boxShadow:shadow.card,
          }}>
            デフォルトのままシェア
          </button>
        )}

      </div>
    </div>
  );
}
